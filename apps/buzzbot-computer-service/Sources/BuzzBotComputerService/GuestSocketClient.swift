import BuzzBotProtocol
import Darwin
import Foundation
@preconcurrency import Virtualization

/// Host-side client that connects to the guest helper over a VZVirtioSocketDevice.
///
/// The host sends a `GuestCommandRequest` as newline-delimited JSON, then reads
/// back a single `GuestCommandResponse`. All recording and playback happens
/// inside the guest; the host receives metadata only.
///
/// This class is intentionally thin: no retry, no crypto, no authority.
@MainActor
final class GuestSocketClient: NSObject {
    /// Vsock port the guest helper listens on.
    static let guestPort: UInt32 = 2222

    private static let connectTimeout: TimeInterval = 5
    private static let writeTimeout: TimeInterval = 5
    private static let readTimeout: TimeInterval = 15
    private static let maximumResponseBytes = 64 * 1024

    private let socketDevice: VZVirtioSocketDevice

    /// Set to an error string when the most recent request fails.
    private(set) var lastError: String?

    /// True only while at least one connected request is actively exchanging its frame.
    private(set) var isConnected = false
    private var activeConnectionCount = 0

    init(socketDevice: VZVirtioSocketDevice) {
        self.socketDevice = socketDevice
        super.init()
    }

    // MARK: - Public API

    /// Send a request to the guest helper and await the response.
    func send(_ request: GuestCommandRequest) async throws -> GuestCommandResponse {
        lastError = nil

        let requestData: Data
        do {
            requestData = try GuestCommandCodec.encode(request)
        } catch {
            throw record(.encodeFailed(error.localizedDescription))
        }

        let connection: VZVirtioSocketConnection
        do {
            connection = try await connectWithTimeout()
        } catch let error as GuestSocketError {
            throw record(error)
        } catch {
            throw record(.connectFailed(error.localizedDescription))
        }

        let responseData: Data
        do {
            responseData = try await exchange(connection: connection, requestData: requestData)
        } catch let error as GuestSocketError {
            throw record(error)
        } catch {
            throw record(.ioFailed(error.localizedDescription))
        }

        do {
            return try GuestCommandCodec.decodeResponse(from: responseData).0
        } catch {
            throw record(.decodeFailed(error.localizedDescription))
        }
    }

    // MARK: - Connection handling

    private func exchange(
        connection: VZVirtioSocketConnection,
        requestData: Data
    ) async throws -> Data {
        activeConnectionCount += 1
        isConnected = true
        defer {
            activeConnectionCount -= 1
            isConnected = activeConnectionCount > 0
        }

        let connectionBox = GuestSocketConnectionBox(connection)
        let writeTimeout = Self.writeTimeout
        let readTimeout = Self.readTimeout
        let maximumResponseBytes = Self.maximumResponseBytes

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try GuestSocketIO.exchange(
                        connection: connectionBox.connection,
                        requestData: requestData,
                        writeTimeout: writeTimeout,
                        readTimeout: readTimeout,
                        maximumResponseBytes: maximumResponseBytes
                    )
                })
            }
        }
    }

    private func connectWithTimeout() async throws -> VZVirtioSocketConnection {
        let timeout = Self.connectTimeout
        let connectionBox: GuestSocketConnectionBox = try await withCheckedThrowingContinuation { continuation in
            let attempt = GuestSocketConnectAttempt(continuation: continuation)

            socketDevice.connect(toPort: Self.guestPort) { result in
                switch result {
                case .success(let connection):
                    attempt.complete(connection: connection, error: nil)
                case .failure(let error):
                    attempt.complete(connection: nil, error: error)
                }
            }

            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + timeout
            ) {
                attempt.timeout(after: timeout)
            }
        }
        return connectionBox.connection
    }

    private func record(_ error: GuestSocketError) -> GuestSocketError {
        lastError = error.localizedDescription
        return error
    }
}

/// Synchronizes the VZ completion handler with the finite connection timer.
/// A connection that arrives after the timeout is immediately closed.
private final class GuestSocketConnectAttempt: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private let continuation: CheckedContinuation<GuestSocketConnectionBox, Error>

    init(continuation: CheckedContinuation<GuestSocketConnectionBox, Error>) {
        self.continuation = continuation
    }

    func complete(connection: VZVirtioSocketConnection?, error: Error?) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            connection?.close()
            return
        }
        isFinished = true
        lock.unlock()

        if let connection {
            continuation.resume(returning: GuestSocketConnectionBox(connection))
        } else {
            continuation.resume(
                throwing: GuestSocketError.connectFailed(
                    error?.localizedDescription ?? "Virtualization returned no connection."
                )
            )
        }
    }

    func timeout(after seconds: TimeInterval) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()
        continuation.resume(throwing: GuestSocketError.connectTimedOut(seconds: seconds))
    }
}

/// Explicitly permits moving the VZ connection to the dedicated blocking-I/O queue.
private final class GuestSocketConnectionBox: @unchecked Sendable {
    let connection: VZVirtioSocketConnection

    init(_ connection: VZVirtioSocketConnection) {
        self.connection = connection
    }
}

/// Performs all file-descriptor work away from the main actor.
private enum GuestSocketIO {
    static func exchange(
        connection: VZVirtioSocketConnection,
        requestData: Data,
        writeTimeout: TimeInterval,
        readTimeout: TimeInterval,
        maximumResponseBytes: Int
    ) throws -> Data {
        defer { connection.close() }

        let fileDescriptor = connection.fileDescriptor
        let currentFlags = fcntl(fileDescriptor, F_GETFL)
        guard currentFlags >= 0 else {
            throw socketConfigurationError()
        }
        guard fcntl(fileDescriptor, F_SETFL, currentFlags | O_NONBLOCK) >= 0 else {
            throw socketConfigurationError()
        }

        // Prevent a peer close during write from terminating the host process.
        var enabled: Int32 = 1
        guard setsockopt(
            fileDescriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &enabled,
            socklen_t(MemoryLayout.size(ofValue: enabled))
        ) == 0 else {
            throw socketConfigurationError()
        }

        try writeAll(requestData, to: fileDescriptor, timeout: writeTimeout)
        return try readFrame(
            from: fileDescriptor,
            timeout: readTimeout,
            maximumBytes: maximumResponseBytes
        )
    }

    private static func writeAll(_ data: Data, to fileDescriptor: Int32, timeout: TimeInterval) throws {
        let deadline = makeDeadline(after: timeout)
        var totalWritten = 0

        try data.withUnsafeBytes { bytes in
            while totalWritten < bytes.count {
                try waitUntilReady(
                    fileDescriptor,
                    events: Int16(POLLOUT),
                    deadline: deadline,
                    timeoutError: .writeTimedOut(seconds: timeout),
                    failure: { .writeFailed(code: $0, message: $1) }
                )

                guard let baseAddress = bytes.baseAddress else {
                    throw GuestSocketError.incompleteWrite(bytesWritten: totalWritten, expected: bytes.count)
                }
                let result = Darwin.write(
                    fileDescriptor,
                    baseAddress.advanced(by: totalWritten),
                    bytes.count - totalWritten
                )

                if result > 0 {
                    totalWritten += result
                } else if result == 0 {
                    throw GuestSocketError.incompleteWrite(
                        bytesWritten: totalWritten,
                        expected: bytes.count
                    )
                } else {
                    let code = errno
                    if code == EINTR || code == EAGAIN || code == EWOULDBLOCK {
                        continue
                    }
                    throw GuestSocketError.writeFailed(code: code, message: errorMessage(for: code))
                }
            }
        }

        guard totalWritten == data.count else {
            throw GuestSocketError.incompleteWrite(bytesWritten: totalWritten, expected: data.count)
        }
    }

    private static func readFrame(
        from fileDescriptor: Int32,
        timeout: TimeInterval,
        maximumBytes: Int
    ) throws -> Data {
        let deadline = makeDeadline(after: timeout)
        var response = Data()
        response.reserveCapacity(min(maximumBytes, 4096))
        var temporary = [UInt8](repeating: 0, count: 4096)

        while true {
            try waitUntilReady(
                fileDescriptor,
                events: Int16(POLLIN),
                deadline: deadline,
                timeoutError: .readTimedOut(seconds: timeout),
                failure: { .readFailed(code: $0, message: $1) }
            )

            let count = temporary.withUnsafeMutableBytes { bytes in
                Darwin.read(fileDescriptor, bytes.baseAddress, bytes.count)
            }

            if count > 0 {
                let received = temporary[0..<count]
                if let delimiterIndex = received.firstIndex(of: GuestCommandCodec.delimiter) {
                    let throughDelimiter = received[received.startIndex...delimiterIndex]
                    guard response.count + throughDelimiter.count <= maximumBytes else {
                        throw GuestSocketError.responseTooLarge(limit: maximumBytes)
                    }
                    response.append(contentsOf: throughDelimiter)
                    return response
                }

                guard response.count + received.count < maximumBytes else {
                    throw GuestSocketError.responseTooLarge(limit: maximumBytes)
                }
                response.append(contentsOf: received)
            } else if count == 0 {
                throw GuestSocketError.connectionClosedBeforeResponse
            } else {
                let code = errno
                if code == EINTR || code == EAGAIN || code == EWOULDBLOCK {
                    continue
                }
                throw GuestSocketError.readFailed(code: code, message: errorMessage(for: code))
            }
        }
    }

    private static func waitUntilReady(
        _ fileDescriptor: Int32,
        events: Int16,
        deadline: UInt64,
        timeoutError: GuestSocketError,
        failure: (Int32, String) -> GuestSocketError
    ) throws {
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { throw timeoutError }

            let remainingNanoseconds = deadline - now
            let remainingMilliseconds = max(
                1,
                min(UInt64(Int32.max), (remainingNanoseconds + 999_999) / 1_000_000)
            )
            var descriptor = pollfd(fd: fileDescriptor, events: events, revents: 0)
            let result = Darwin.poll(&descriptor, 1, Int32(remainingMilliseconds))

            if result > 0 {
                if descriptor.revents & Int16(POLLNVAL) != 0 {
                    throw failure(EBADF, errorMessage(for: EBADF))
                }
                if descriptor.revents & (events | Int16(POLLERR) | Int16(POLLHUP)) != 0 {
                    return
                }
                continue
            }
            if result == 0 {
                throw timeoutError
            }

            let code = errno
            if code == EINTR { continue }
            throw failure(code, errorMessage(for: code))
        }
    }

    private static func makeDeadline(after seconds: TimeInterval) -> UInt64 {
        let interval = UInt64(max(0, seconds) * 1_000_000_000)
        let now = DispatchTime.now().uptimeNanoseconds
        return now.addingReportingOverflow(interval).partialValue
    }

    private static func socketConfigurationError() -> GuestSocketError {
        let code = errno
        return .socketConfigurationFailed(code: code, message: errorMessage(for: code))
    }

    private static func errorMessage(for code: Int32) -> String {
        String(cString: strerror(code))
    }
}

enum GuestSocketError: Error, LocalizedError {
    case connectTimedOut(seconds: TimeInterval)
    case connectFailed(String)
    case encodeFailed(String)
    case socketConfigurationFailed(code: Int32, message: String)
    case writeTimedOut(seconds: TimeInterval)
    case writeFailed(code: Int32, message: String)
    case incompleteWrite(bytesWritten: Int, expected: Int)
    case readTimedOut(seconds: TimeInterval)
    case readFailed(code: Int32, message: String)
    case connectionClosedBeforeResponse
    case responseTooLarge(limit: Int)
    case decodeFailed(String)
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectTimedOut(let seconds):
            return "Guest socket connection timed out after \(seconds) seconds."
        case .connectFailed(let message):
            return "Guest socket connection failed: \(message)"
        case .encodeFailed(let message):
            return "Guest request encoding failed: \(message)"
        case .socketConfigurationFailed(let code, let message):
            return "Guest socket configuration failed (errno \(code)): \(message)"
        case .writeTimedOut(let seconds):
            return "Guest socket write timed out after \(seconds) seconds."
        case .writeFailed(let code, let message):
            return "Guest socket write failed (errno \(code)): \(message)"
        case .incompleteWrite(let bytesWritten, let expected):
            return "Guest socket closed after writing \(bytesWritten) of \(expected) bytes."
        case .readTimedOut(let seconds):
            return "Guest socket read timed out after \(seconds) seconds."
        case .readFailed(let code, let message):
            return "Guest socket read failed (errno \(code)): \(message)"
        case .connectionClosedBeforeResponse:
            return "Guest socket closed before a complete response was received."
        case .responseTooLarge(let limit):
            return "Guest response exceeded the \(limit)-byte limit."
        case .decodeFailed(let message):
            return "Guest response decoding failed: \(message)"
        case .ioFailed(let message):
            return "Guest socket I/O failed: \(message)"
        }
    }
}
