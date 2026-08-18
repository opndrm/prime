import AppKit
import Darwin
import Foundation

/// The native viewer's deliberately narrow read-only protocol. A producer
/// accepts one owner-generated token and then closes the socket after one PPM
/// frame. There are no input, clipboard, file, or shell messages.
struct UnixFrameReceiver {
    static let maximumWidth = 3_840
    static let maximumHeight = 2_160
    static let maximumFrameBytes = 24 * 1_024 * 1_024
    static let receiveTimeoutSeconds: Int = 4

    struct Configuration: Sendable {
        let socketPath: String
        let token: String

        /// A normal app launch has no contract and never opens a socket.
        static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Configuration? {
            guard let socketPath = environment["BUZZ_CONTAINER_VIEW_SOCKET"],
                  let token = environment["BUZZ_CONTAINER_VIEW_TOKEN"],
                  socketPath.hasPrefix("/"),
                  !token.isEmpty,
                  token.utf8.count <= 256 else { return nil }
            return Configuration(socketPath: socketPath, token: token)
        }
    }

    enum FrameError: Error, Equatable {
        case unavailable
        case unsafeSocket
        case timedOut
        case frameTooLarge
        case invalidPPM
    }

    static func receiveOnce(_ configuration: Configuration) throws -> NSImage {
        try verifyOwnerOnlySocket(at: configuration.socketPath)
        let descriptor = try connect(to: configuration.socketPath)
        defer { _ = Darwin.close(descriptor) }
        try sendAll(Data((configuration.token + "\n").utf8), to: descriptor)
        return try decodePPM(try readBoundedFrame(from: descriptor))
    }

    static func decodePPM(_ data: Data) throws -> NSImage {
        let bytes = [UInt8](data)
        var index = 0
        func skipHeaderSpaceAndComments() {
            while index < bytes.count {
                if bytes[index].isWhitespace { index += 1 }
                else if bytes[index] == 35 { while index < bytes.count && bytes[index] != 10 { index += 1 } }
                else { return }
            }
        }
        func token() throws -> String {
            skipHeaderSpaceAndComments()
            let start = index
            while index < bytes.count && !bytes[index].isWhitespace && bytes[index] != 35 { index += 1 }
            guard start < index, let value = String(bytes: bytes[start..<index], encoding: .utf8) else { throw FrameError.invalidPPM }
            return value
        }
        guard try token() == "P6",
              let width = Int(try token()), let height = Int(try token()),
              try token() == "255", width > 0, height > 0,
              width <= maximumWidth, height <= maximumHeight else { throw FrameError.invalidPPM }

        // The controlled producer emits exactly one LF separator. Requiring it
        // avoids consuming a valid first pixel value that happens to be space.
        guard index < bytes.count, bytes[index] == 10 else { throw FrameError.invalidPPM }
        let pixelStart = index + 1
        let expected = width * height * 3
        guard expected <= maximumFrameBytes else { throw FrameError.frameTooLarge }
        guard bytes.count - pixelStart == expected else { throw FrameError.invalidPPM }
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: width * 3, bitsPerPixel: 24) else { throw FrameError.invalidPPM }
        data.withUnsafeBytes { source in
            guard let sourceBase = source.baseAddress, let destination = bitmap.bitmapData else { return }
            memcpy(destination, sourceBase.advanced(by: pixelStart), expected)
        }
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmap)
        return image
    }

    private static func verifyOwnerOnlySocket(at path: String) throws {
        var socketInfo = stat()
        guard Darwin.lstat(path, &socketInfo) == 0,
              (socketInfo.st_mode & S_IFMT) == S_IFSOCK,
              socketInfo.st_uid == Darwin.getuid(),
              (socketInfo.st_mode & 0o077) == 0 else { throw FrameError.unsafeSocket }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        var parentInfo = stat()
        guard Darwin.lstat(parent, &parentInfo) == 0,
              (parentInfo.st_mode & S_IFMT) == S_IFDIR,
              parentInfo.st_uid == Darwin.getuid(),
              (parentInfo.st_mode & 0o022) == 0 else { throw FrameError.unsafeSocket }
    }

    private static func connect(to path: String) throws -> Int32 {
        let pathBytes = Array(path.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { throw FrameError.unavailable }
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw FrameError.unavailable }
        var timeout = timeval(tv_sec: receiveTimeoutSeconds, tv_usec: 0)
        guard Darwin.setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
            _ = Darwin.close(descriptor); throw FrameError.unavailable
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.initializeMemory(as: UInt8.self, repeating: 0)
            raw.baseAddress!.copyMemory(from: pathBytes, byteCount: pathBytes.count)
        }
        let length = socklen_t(MemoryLayout<sa_family_t>.size + pathBytes.count + 1)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(descriptor, $0, length) }
        }
        guard result == 0 else { _ = Darwin.close(descriptor); throw FrameError.unavailable }
        return descriptor
    }

    private static func sendAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { raw in
            guard var pointer = raw.bindMemory(to: UInt8.self).baseAddress else { throw FrameError.unavailable }
            var remaining = data.count
            while remaining > 0 {
                let sent = Darwin.send(descriptor, pointer, remaining, 0)
                guard sent > 0 else { throw FrameError.unavailable }
                remaining -= sent; pointer = pointer.advanced(by: sent)
            }
        }
    }

    private static func readBoundedFrame(from descriptor: Int32) throws -> Data {
        var result = Data(); var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
        while true {
            let received = Darwin.recv(descriptor, &buffer, buffer.count, 0)
            if received == 0 { return result }
            if received < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK { throw FrameError.timedOut }
                throw FrameError.unavailable
            }
            guard result.count + received <= maximumFrameBytes else { throw FrameError.frameTooLarge }
            result.append(buffer, count: received)
        }
    }
}

/// Receives at most one frame per second. Socket work stays off the main actor.
final class VisualFrameSession: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false

    @MainActor
    func startIfConfigured(state: ContainerPresentationState) {
        guard let configuration = UnixFrameReceiver.Configuration.fromEnvironment() else { return }
        lock.lock(); stopped = false; lock.unlock()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            while !self.isStopped {
                let result = Result { try UnixFrameReceiver.receiveOnce(configuration) }
                DispatchQueue.main.async { [weak self, weak state] in
                    guard let self, !self.isStopped, let state else { return }
                    switch result {
                    case .success(let image): state.applyViewOnlyFrame(image)
                    case .failure: state.markLiveViewUnavailable()
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    func stop() { lock.lock(); stopped = true; lock.unlock() }
    private var isStopped: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

private extension UInt8 { var isWhitespace: Bool { self == 10 || self == 13 || self == 32 || self == 9 } }
