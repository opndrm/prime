import AppKit
import OPNDRMGuestEngine
import OPNDRMProtocol
import Darwin
import Foundation

/// Guest-side AF_VSOCK helper. The wire carries commands and small metadata only;
/// OpenAdapt processes, artifacts, consent, and review remain in the macOS guest.

private let AF_VSOCK: Int32 = 40
private let VMADDR_CID_ANY: UInt32 = 0xFFFFFFFF

private struct sockaddr_vm {
    var svm_len: UInt8 = UInt8(MemoryLayout<sockaddr_vm>.size)
    var svm_family: UInt8 = 0
    var svm_reserved1: UInt16 = 0
    var svm_port: UInt32 = 0
    var svm_cid: UInt32 = 0
}

private func writeAll(_ fileDescriptor: Int32, _ data: Data) {
    data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else { return }
        var offset = 0
        while offset < bytes.count {
            let written = Darwin.write(
                fileDescriptor,
                baseAddress.advanced(by: offset),
                bytes.count - offset
            )
            if written <= 0 { return }
            offset += written
        }
    }
}

@MainActor
private final class VsockServer {
    static let port: UInt16 = 2222

    private let engine: OpenAdaptGuestEngine
    private var listenFileDescriptor: Int32 = -1

    init(engine: OpenAdaptGuestEngine) {
        self.engine = engine
    }

    func start() throws {
        listenFileDescriptor = socket(AF_VSOCK, SOCK_STREAM, 0)
        guard listenFileDescriptor >= 0 else { throw SocketError.socket }

        var address = sockaddr_vm()
        address.svm_family = UInt8(AF_VSOCK)
        address.svm_port = UInt32(Self.port)
        address.svm_cid = VMADDR_CID_ANY

        let bindResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(
                    listenFileDescriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_vm>.size)
                )
            }
        }
        guard bindResult == 0 else {
            close(listenFileDescriptor)
            throw SocketError.bind
        }
        guard listen(listenFileDescriptor, 8) == 0 else {
            close(listenFileDescriptor)
            throw SocketError.listen
        }

        FileHandle.standardError.write(
            Data("OPNDRMGuest: listening on vsock port \(Self.port)\n".utf8)
        )
        while true {
            let client = accept(listenFileDescriptor, nil, nil)
            if client < 0 { continue }
            handleClient(client)
            close(client)
        }
    }

    private func handleClient(_ fileDescriptor: Int32) {
        var buffer = Data(capacity: 4096)
        var chunk = [UInt8](repeating: 0, count: 4096)
        while buffer.firstIndex(of: GuestCommandCodec.delimiter) == nil,
              buffer.count <= 64 * 1024 {
            let count = Darwin.read(fileDescriptor, &chunk, chunk.count)
            if count <= 0 { break }
            buffer.append(contentsOf: chunk[0..<count])
        }

        let response: GuestCommandResponse
        if let request = try? GuestCommandCodec.decodeRequest(from: buffer).0 {
            response = engine.handle(request)
        } else {
            response = GuestCommandResponse(ok: false, message: "invalid request")
        }
        if let frame = try? GuestCommandCodec.encode(response) {
            writeAll(fileDescriptor, frame)
        }
    }
}

@MainActor
private final class GuestVisibleRecordingConsent: RecordingConsentProviding {
    func requestConsent(name: String, capturesVideo: Bool, capturesAudio: Bool) -> Bool {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Allow guest-only recording?"
        let media = [
            capturesVideo ? "guest display and input events" : nil,
            capturesAudio ? "guest audio" : nil,
        ].compactMap { $0 }.joined(separator: " and ")
        alert.informativeText = """
        Recording “\(name)” will capture \(media) inside this macOS guest. Artifacts stay in the guest and review opens in the guest browser. The host receives only status plus recording name, date, and size.

        Decline is the default. OpenAdapt Desktop and its dashboard will not be opened.
        """
        alert.addButton(withTitle: "Decline")
        alert.addButton(withTitle: "Allow This Recording")
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        return alert.runModal() == .alertSecondButtonReturn
    }
}

private enum SocketError: Error, LocalizedError {
    case socket
    case bind
    case listen

    var errorDescription: String? {
        switch self {
        case .socket: return "AF_VSOCK socket creation failed"
        case .bind: return "AF_VSOCK bind failed"
        case .listen: return "AF_VSOCK listen failed"
        }
    }
}

@main
private struct OPNDRMGuestHelper {
    @MainActor
    static func main() {
        let environment = ProcessInfo.processInfo.environment
        guard let openAdaptPath = environment["OPENADAPT_PATH"],
              openAdaptPath.hasPrefix("/") else {
            fail("OPENADAPT_PATH is missing or not absolute")
        }
        guard let recordingsPath = environment["OPENADAPT_RECORDINGS_DIR"],
              recordingsPath.hasPrefix("/") else {
            fail("OPENADAPT_RECORDINGS_DIR is missing or not absolute")
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let recordingRoot = URL(fileURLWithPath: recordingsPath).standardizedFileURL
        guard recordingRoot.path.hasPrefix(home.path + "/") else {
            fail("OPENADAPT_RECORDINGS_DIR must stay inside the guest user's home")
        }

        do {
            let captureScript: URL? = {
                if let path = ProcessInfo.processInfo.environment["CAPTURE_SCRIPT"],
                   !path.isEmpty {
                    let url = URL(fileURLWithPath: path)
                    return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
                }
                // Default: look for ff-record.sh next to the helper
                let defaultScript = URL(fileURLWithPath: openAdaptPath)
                    .deletingLastPathComponent()
                    .appendingPathComponent("ff-record.sh")
                return FileManager.default.isExecutableFile(atPath: defaultScript.path) ? defaultScript : nil
            }()

            let engine = try OpenAdaptGuestEngine(
                openAdaptExecutable: URL(fileURLWithPath: openAdaptPath),
                recordingsDirectory: recordingRoot,
                consentProvider: GuestVisibleRecordingConsent(),
                captureScript: captureScript
            )
            try VsockServer(engine: engine).start()
        } catch {
            fail("startup failed: \(error.localizedDescription)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("OPNDRMGuest: \(message)\n".utf8))
        exit(1)
    }
}
