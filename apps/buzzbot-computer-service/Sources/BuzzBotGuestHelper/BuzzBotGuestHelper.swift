import BuzzBotProtocol
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Guest-side helper that listens on AF_VSOCK and translates host requests
/// into guest-installed `openadapt` CLI commands.
///
/// All recording and playback happens inside the guest VM.
/// The host receives metadata (names, dates, sizes) only.
/// No OpenAdapt Desktop.app is launched; only the `openadapt` CLI is used.

// MARK: - VSOCK address helpers

/// sockaddr_vm struct for AF_VSOCK (40).
/// Matches the kernel definition in sys/vsock.h (packed, host byte order).
/// On macOS guest, we bind to VMADDR_CID_ANY so the host can connect.
private let AF_VSOCK: Int32 = 40
private let VMADDR_CID_ANY: UInt32 = 0xFFFFFFFF // -1U

// sockaddr_vm is packed in the kernel definition:
//   uint8_t  svm_len       (total length = 12)
//   uint8_t  svm_family    (AF_VSOCK = 40)
//   uint16_t svm_reserved1
//   uint32_t svm_port       (host byte order)
//   uint32_t svm_cid        (host byte order)
// Total = 12 bytes.
private struct sockaddr_vm {
    var svm_len: UInt8 = UInt8(MemoryLayout<sockaddr_vm>.size)
    var svm_family: UInt8 = 0
    var svm_reserved1: UInt16 = 0
    var svm_port: UInt32 = 0
    var svm_cid: UInt32 = 0
}

// MARK: - VSOCK server

/// Write all bytes to a file descriptor, handling partial writes.
private func writeAll(_ fd: Int32, _ data: Data) {
    data.withUnsafeBytes { buf in
        var remaining = buf.count
        var offset = 0
        while remaining > 0 {
            let written = write(fd, buf.baseAddress!.advanced(by: offset), remaining)
            if written <= 0 { break }
            remaining -= written
            offset += written
        }
    }
}

/// Minimal AF_VSOCK listener that accepts connections, reads a single
/// newline-delimited JSON request, dispatches it, and writes back a response.
final class VsockServer {
    static let port: UInt16 = 2222

    private var listenFd: Int32 = -1
    private let handler: CommandHandler

    init(handler: CommandHandler) {
        self.handler = handler
    }

    func start() throws {
        listenFd = socket(AF_VSOCK, SOCK_STREAM, 0)
        guard listenFd >= 0 else {
            throw NSError(domain: "vsock", code: 1, userInfo: [NSLocalizedDescriptionKey: "socket() failed"])
        }

        // Bind to VMADDR_CID_ANY on the guest port.
        // svm_port and svm_cid are in host byte order per sys/vsock.h.
        var addr = sockaddr_vm()
        addr.svm_len = UInt8(MemoryLayout<sockaddr_vm>.size)
        addr.svm_family = UInt8(AF_VSOCK)
        addr.svm_port = UInt32(Self.port) // host byte order
        addr.svm_cid = VMADDR_CID_ANY     // host byte order

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(listenFd, sa, socklen_t(MemoryLayout<sockaddr_vm>.size))
            }
        }
        guard bindResult == 0 else {
            close(listenFd)
            throw NSError(domain: "vsock", code: 2, userInfo: [NSLocalizedDescriptionKey: "bind() failed"])
        }

        guard listen(listenFd, 8) == 0 else {
            close(listenFd)
            throw NSError(domain: "vsock", code: 3, userInfo: [NSLocalizedDescriptionKey: "listen() failed"])
        }

        FileHandle.standardError.write(Data("BuzzBotGuest: listening on vsock port \(Self.port)\n".utf8))

        // Accept loop (blocking, single-threaded — thin helper).
        while true {
            let clientFd = accept(listenFd, nil, nil)
            if clientFd < 0 { continue }
            handleClient(clientFd)
            close(clientFd)
        }
    }

    func stop() {
        if listenFd >= 0 { close(listenFd); listenFd = -1 }
    }

    private func handleClient(_ fd: Int32) {
        // Read until we find a newline (max 64KB).
        var buffer = Data(capacity: 65536)
        var tmp = [UInt8](repeating: 0, count: 4096)
        while buffer.firstIndex(of: GuestCommandCodec.delimiter) == nil {
            let n = read(fd, &tmp, tmp.count)
            if n <= 0 { break }
            buffer.append(contentsOf: tmp[0..<n])
            if buffer.count > 65536 { break }
        }

        guard let req = try? GuestCommandCodec.decodeRequest(from: buffer).0 else {
            let errResp = GuestCommandResponse(ok: false, message: "invalid request", recordings: nil, guestVersion: nil)
            if let data = try? GuestCommandCodec.encode(errResp) {
                writeAll(fd, data)
            }
            return
        }

        let response = handler.handle(req)
        if let data = try? GuestCommandCodec.encode(response) {
            writeAll(fd, data)
        }
    }
}

// MARK: - Process pipe collector

/// Thread-safe collector for pipe data, using a lock to protect concurrent
/// mutations from readability handler callbacks.
final class PipeDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _stdoutData = Data()
    private var _stderrData = Data()

    var stdoutData: Data {
        lock.lock(); defer { lock.unlock() }
        return _stdoutData
    }
    var stderrData: Data {
        lock.lock(); defer { lock.unlock() }
        return _stderrData
    }

    func appendStdout(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        _stdoutData.append(data)
    }

    func appendStderr(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        _stderrData.append(data)
    }
}

// MARK: - Command handler (dispatches to openadapt CLI)

final class CommandHandler {
    private let openadaptPath: String
    private var currentRecordingName: String?

    init(openadaptPath: String) {
        self.openadaptPath = openadaptPath
    }

    func handle(_ request: GuestCommandRequest) -> GuestCommandResponse {
        switch request.action {
        case .status:
            return GuestCommandResponse(
                ok: true,
                message: "guest helper ready",
                recordings: nil,
                guestVersion: "1.0.0"
            )

        case .recordStart:
            guard let name = request.name, !name.isEmpty else {
                return GuestCommandResponse(ok: false, message: "record.start requires a name", recordings: nil, guestVersion: nil)
            }
            if let currentRecordingName {
                return GuestCommandResponse(ok: false, message: "already recording: \(currentRecordingName)", recordings: nil, guestVersion: nil)
            }
            let video = request.video ?? true
            let audio = request.audio ?? false

            // Build the openadapt command:
            //   openadapt capture start --name <id> --video --no-audio
            // The CLI runs headless inside the guest — no Desktop.app.
            var args = [openadaptPath, "capture", "start", "--name", name]
            if video { args.append("--video") }
            if !audio { args.append("--no-audio") }

            do {
                let result = try runProcess(executable: openadaptPath, args: args)
                if result.exitCode == 0 {
                    currentRecordingName = name
                    return GuestCommandResponse(ok: true, message: "recording started: \(name)", recordings: nil, guestVersion: nil)
                } else {
                    return GuestCommandResponse(ok: false, message: "openadapt capture start failed: \(result.stderr)", recordings: nil, guestVersion: nil)
                }
            } catch {
                return GuestCommandResponse(ok: false, message: "openadapt invocation failed: \(error.localizedDescription)", recordings: nil, guestVersion: nil)
            }

        case .recordStop:
            //   openadapt capture stop
            do {
                let result = try runProcess(executable: openadaptPath, args: [openadaptPath, "capture", "stop"])
                if result.exitCode == 0 {
                    currentRecordingName = nil
                    return GuestCommandResponse(ok: true, message: "recording stopped", recordings: nil, guestVersion: nil)
                } else {
                    return GuestCommandResponse(ok: false, message: "openadapt capture stop failed: \(result.stderr)", recordings: nil, guestVersion: nil)
                }
            } catch {
                return GuestCommandResponse(ok: false, message: "openadapt invocation failed: \(error.localizedDescription)", recordings: nil, guestVersion: nil)
            }

        case .recordingsList:
            //   openadapt capture list
            do {
                let result = try runProcess(executable: openadaptPath, args: [openadaptPath, "capture", "list"])
                if result.exitCode == 0 {
                    // No supported machine-readable output contract for this
                    // OpenAdapt command is documented in this service. Do not
                    // invent dates or sizes by interpreting human-readable text.
                    return GuestCommandResponse(
                        ok: false,
                        message: "recordings.list unsupported: OpenAdapt CLI machine-readable list format is not established",
                        recordings: nil,
                        guestVersion: nil
                    )
                } else {
                    return GuestCommandResponse(ok: false, message: "openadapt capture list failed: \(result.stderr)", recordings: nil, guestVersion: nil)
                }
            } catch {
                return GuestCommandResponse(ok: false, message: "openadapt invocation failed: \(error.localizedDescription)", recordings: nil, guestVersion: nil)
            }

        case .recordingPlay:
            //   openadapt capture view <id> --open
            // Playback opens inside the guest VM, not on the host.
            guard let name = request.name, !name.isEmpty else {
                return GuestCommandResponse(ok: false, message: "recording.play requires a name", recordings: nil, guestVersion: nil)
            }
            do {
                let result = try runProcess(executable: openadaptPath, args: [openadaptPath, "capture", "view", name, "--open"])
                if result.exitCode == 0 {
                    return GuestCommandResponse(ok: true, message: "playing: \(name)", recordings: nil, guestVersion: nil)
                } else {
                    return GuestCommandResponse(ok: false, message: "openadapt capture view failed: \(result.stderr)", recordings: nil, guestVersion: nil)
                }
            } catch {
                return GuestCommandResponse(ok: false, message: "openadapt invocation failed: \(error.localizedDescription)", recordings: nil, guestVersion: nil)
            }
        }
    }

    // MARK: - Process runner

    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private func runProcess(executable: String, args: [String]) throws -> ProcessResult {
        // args[0] is the executable path, rest are arguments.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Drain both pipes on independent readers so a verbose child cannot
        // fill a pipe and block. Every wait below is bounded; an unexpected
        // Foundation EOF/readability edge case cannot hang the helper forever.
        let collector = PipeDataCollector()
        let readers = DispatchGroup()
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            collector.appendStdout(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            collector.appendStderr(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }

        let terminated = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in terminated.signal() }
        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            throw error
        }

        if terminated.wait(timeout: .now() + 60) == .timedOut {
            process.terminate()
            if terminated.wait(timeout: .now() + 5) == .timedOut {
                // A wedged child must not retain the pipe readers forever.
                _ = kill(process.processIdentifier, SIGKILL)
                _ = terminated.wait(timeout: .now() + 2)
            }
            if readers.wait(timeout: .now() + 2) == .timedOut {
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
            }
            throw NSError(
                domain: "openadapt-process",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "openadapt command timed out"]
            )
        }

        guard readers.wait(timeout: .now() + 5) == .success else {
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            throw NSError(
                domain: "openadapt-process",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "timed out collecting openadapt output"]
            )
        }

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: collector.stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: collector.stderrData, encoding: .utf8) ?? ""
        )
    }


}

// MARK: - Main entry point

@main
struct BuzzBotGuestHelper {
    static func main() {
        // The installer records the exact guest CLI executable in the
        // LaunchAgent. Never guess a host application or a machine-wide path.
        guard let openadaptPath = ProcessInfo.processInfo.environment["OPENADAPT_PATH"],
              openadaptPath.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: openadaptPath) else {
            FileHandle.standardError.write(Data("BuzzBotGuest: OPENADAPT_PATH is missing or not executable\n".utf8))
            exit(1)
        }

        let handler = CommandHandler(openadaptPath: openadaptPath)
        let server = VsockServer(handler: handler)

        do {
            try server.start()
        } catch {
            FileHandle.standardError.write(Data("BuzzBotGuest: failed to start: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}