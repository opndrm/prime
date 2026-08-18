import OPNDRMProtocol
import Darwin
import Foundation

/// Explicit, guest-visible consent. Production uses a native macOS alert in the guest;
/// tests may provide a deterministic implementation without touching the desktop.
@MainActor
public protocol RecordingConsentProviding {
    func requestConsent(name: String, capturesVideo: Bool, capturesAudio: Bool) -> Bool
}

/// Owns one OpenAdapt CLI capture process and guest-local recording artifacts.
/// It never starts OpenAdapt Desktop or a dashboard and never returns artifact bytes.
@MainActor
public final class OpenAdaptGuestEngine {
    public static let guestVersion = "1.1.0"
    private static let completionMarkerName = ".opndrm-vm-openadapt-complete"
    private static let completionMarkerContents = "opndrm-vm-openadapt-capture/v1\n"

    private let openAdaptExecutable: URL
    private let recordingsDirectory: URL
    private let consentProvider: RecordingConsentProviding
    private let startupTimeout: TimeInterval
    private let stopTimeout: TimeInterval
    private let commandTimeout: TimeInterval
    private let captureScript: URL?
    private var activeCapture: CaptureSession?

    public init(
        openAdaptExecutable: URL,
        recordingsDirectory: URL,
        consentProvider: RecordingConsentProviding,
        startupTimeout: TimeInterval = 15,
        stopTimeout: TimeInterval = 30,
        commandTimeout: TimeInterval = 60,
        captureScript: URL? = nil
    ) throws {
        guard openAdaptExecutable.path.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: openAdaptExecutable.path) else {
            throw EngineError.invalidOpenAdaptExecutable
        }
        guard recordingsDirectory.path.hasPrefix("/") else {
            throw EngineError.invalidRecordingsDirectory
        }
        self.openAdaptExecutable = openAdaptExecutable.standardizedFileURL
        self.recordingsDirectory = recordingsDirectory.standardizedFileURL
        self.consentProvider = consentProvider
        self.startupTimeout = startupTimeout
        self.stopTimeout = stopTimeout
        self.commandTimeout = commandTimeout
        self.captureScript = captureScript
        try Self.preparePrivateDirectory(self.recordingsDirectory)
    }

    public func handle(_ request: GuestCommandRequest) -> GuestCommandResponse {
        reapExitedCapture()

        switch request.action {
        case .status:
            let message: String
            if let activeCapture {
                message = "guest helper ready; recording active: \(activeCapture.name)"
            } else {
                message = "guest helper ready; no recording active"
            }
            return GuestCommandResponse(
                ok: true,
                message: message,
                guestVersion: Self.guestVersion
            )

        case .recordStart:
            return startRecording(request)

        case .recordStop:
            return stopRecording()

        case .recordingsList:
            return listRecordings()

        case .recordingPlay:
            return playRecording(named: request.name)
        }
    }

    private func startRecording(_ request: GuestCommandRequest) -> GuestCommandResponse {
        guard let name = request.name, Self.isValidRecordingName(name) else {
            return failure("record.start requires a safe recording name")
        }
        guard activeCapture == nil else {
            return failure("a guest recording is already active")
        }

        let artifactDirectory = recordingsDirectory.appendingPathComponent(name, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: artifactDirectory.path) else {
            return failure("a guest recording with that name already exists")
        }

        let video = request.video ?? true
        let audio = request.audio ?? false
        guard video || audio else {
            return failure("record.start requires video or audio capture")
        }
        guard consentProvider.requestConsent(
            name: name,
            capturesVideo: video,
            capturesAudio: audio
        ) else {
            return failure("guest recording consent was declined")
        }

        let process = Process()
        if let captureScript, FileManager.default.isExecutableFile(atPath: captureScript.path) {
            // FFmpeg-based capture (VM-compatible, no multiprocessing spawn)
            process.executableURL = captureScript
            process.arguments = [
                recordingsDirectory.path,
                name,
                audio ? "--audio" : "",
            ].filter { !$0.isEmpty }
        } else {
            // OpenAdapt capture (original path)
            process.executableURL = openAdaptExecutable
            process.arguments = [
                "capture", "start", "--name", name,
                video ? "--video" : "--no-video",
                audio ? "--audio" : "--no-audio",
            ]
        }
        process.currentDirectoryURL = recordingsDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        let output = ProcessOutput()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        output.drain(stdoutPipe, asStandardError: false)
        output.drain(stderrPipe, asStandardError: true)

        let session = CaptureSession(
            name: name,
            artifactDirectory: artifactDirectory,
            process: process,
            output: output,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe
        )

        do {
            try process.run()
        } catch {
            session.finishReading()
            logGuestOnly("OpenAdapt capture failed to launch: \(error.localizedDescription)")
            return failure("OpenAdapt capture could not be launched in the guest")
        }

        let deadline = Date().addingTimeInterval(startupTimeout)
        while Date() < deadline {
            if output.stdoutString.contains("Recording...") {
                activeCapture = session
                return GuestCommandResponse(
                    ok: true,
                    message: "guest recording started: \(name)"
                )
            }
            if !process.isRunning {
                process.waitUntilExit()
                session.finishReading()
                logProcessFailure("OpenAdapt capture exited before readiness", session: session)
                return failure("OpenAdapt capture did not become ready in the guest")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        _ = stop(session: session, timeout: 5)
        logProcessFailure("OpenAdapt capture readiness timed out", session: session)
        return failure("OpenAdapt capture readiness timed out in the guest")
    }

    private func stopRecording() -> GuestCommandResponse {
        guard let session = activeCapture else {
            return failure("no guest recording is active")
        }

        let stopped = stop(session: session, timeout: stopTimeout)
        activeCapture = nil
        guard stopped else {
            logProcessFailure("OpenAdapt capture did not stop cleanly", session: session)
            return failure("OpenAdapt capture did not stop cleanly in the guest")
        }

        let database = session.artifactDirectory.appendingPathComponent("recording.db")
        let videoFile = session.artifactDirectory.appendingPathComponent("recording.mp4")
        guard Self.isRegularNonSymlinkFile(database) || Self.isRegularNonSymlinkFile(videoFile) else {
            logGuestOnly("OpenAdapt exited without recording.db for \(session.name)")
            return failure("OpenAdapt stopped without a complete guest recording artifact")
        }
        do {
            let marker = session.artifactDirectory.appendingPathComponent(
                Self.completionMarkerName
            )
            try Data(Self.completionMarkerContents.utf8).write(to: marker, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: marker.path
            )
        } catch {
            logGuestOnly("Unable to mark completed guest recording: \(error.localizedDescription)")
            return failure("OpenAdapt stopped but guest artifact finalization failed")
        }

        return GuestCommandResponse(
            ok: true,
            message: "guest recording stopped and saved: \(session.name)"
        )
    }

    private func stop(session: CaptureSession, timeout: TimeInterval) -> Bool {
        if session.process.isRunning {
            // OpenAdapt's supported capture interaction says Ctrl+C stops capture.
            // Interrupt the exact child we launched; do not call the CLI's current
            // informational `capture stop` command or guess a private IPC format.
            session.process.interrupt()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while session.process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if session.process.isRunning {
            session.process.terminate()
            let terminateDeadline = Date().addingTimeInterval(2)
            while session.process.isRunning, Date() < terminateDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        if session.process.isRunning {
            _ = Darwin.kill(session.process.processIdentifier, SIGKILL)
            let killDeadline = Date().addingTimeInterval(2)
            while session.process.isRunning, Date() < killDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        guard !session.process.isRunning else { return false }
        session.process.waitUntilExit()
        session.finishReading()
        return session.process.terminationStatus == 0
    }

    private func listRecordings() -> GuestCommandResponse {
        do {
            let entries = try FileManager.default.contentsOfDirectory(
                at: recordingsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            var recordings: [GuestRecordingInfo] = []
            for entry in entries {
                guard Self.isValidRecordingName(entry.lastPathComponent) else { continue }
                let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
                let database = entry.appendingPathComponent("recording.db")
                let completionMarker = entry.appendingPathComponent(Self.completionMarkerName)
                guard Self.isRegularNonSymlinkFile(database),
                      Self.isRegularNonSymlinkFile(completionMarker) else { continue }
                let metadata = Self.artifactMetadata(at: entry)
                recordings.append(
                    GuestRecordingInfo(
                        name: entry.lastPathComponent,
                        date: Self.iso8601.string(from: metadata.latestModification),
                        size: metadata.size
                    )
                )
            }
            recordings.sort { lhs, rhs in
                if lhs.date == rhs.date { return lhs.name < rhs.name }
                return lhs.date > rhs.date
            }
            return GuestCommandResponse(
                ok: true,
                message: "\(recordings.count) guest recording(s)",
                recordings: recordings
            )
        } catch {
            logGuestOnly("Unable to enumerate guest recordings: \(error.localizedDescription)")
            return failure("guest recording metadata is unavailable")
        }
    }

    private func playRecording(named optionalName: String?) -> GuestCommandResponse {
        guard activeCapture == nil else {
            return failure("stop the active guest recording before review")
        }
        guard let name = optionalName, Self.isValidRecordingName(name) else {
            return failure("recording.play requires a safe recording name")
        }
        let artifactDirectory = recordingsDirectory.appendingPathComponent(name, isDirectory: true)
        guard Self.isRegularNonSymlinkFile(
            artifactDirectory.appendingPathComponent("recording.db")
        ), Self.isRegularNonSymlinkFile(
            artifactDirectory.appendingPathComponent(Self.completionMarkerName)
        ) else {
            return failure("guest recording was not found")
        }

        let result = runCommand(
            arguments: ["capture", "view", name, "--open"],
            timeout: commandTimeout
        )
        guard let result else {
            return failure("OpenAdapt could not open guest-local review")
        }
        guard result.exitCode == 0 else {
            logGuestOnly(
                "OpenAdapt guest review exited \(result.exitCode): \(result.stderr)"
            )
            return failure("OpenAdapt could not open guest-local review")
        }
        return GuestCommandResponse(
            ok: true,
            message: "guest-local review opened: \(name)"
        )
    }

    private func runCommand(arguments: [String], timeout: TimeInterval) -> CommandResult? {
        let process = Process()
        process.executableURL = openAdaptExecutable
        process.arguments = arguments
        process.currentDirectoryURL = recordingsDirectory
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let output = ProcessOutput()
        output.drain(stdout, asStandardError: false)
        output.drain(stderr, asStandardError: true)

        do {
            try process.run()
        } catch {
            output.stopDraining(stdout, asStandardError: false)
            output.stopDraining(stderr, asStandardError: true)
            logGuestOnly("OpenAdapt command failed to launch: \(error.localizedDescription)")
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            let terminateDeadline = Date().addingTimeInterval(2)
            while process.isRunning, Date() < terminateDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        guard !process.isRunning else {
            _ = Darwin.kill(process.processIdentifier, SIGKILL)
            output.stopDraining(stdout, asStandardError: false)
            output.stopDraining(stderr, asStandardError: true)
            logGuestOnly("OpenAdapt command timed out")
            return nil
        }
        process.waitUntilExit()
        output.stopDraining(stdout, asStandardError: false)
        output.stopDraining(stderr, asStandardError: true)
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: output.stdoutString,
            stderr: output.stderrString
        )
    }

    private func reapExitedCapture() {
        guard let session = activeCapture, !session.process.isRunning else { return }
        session.process.waitUntilExit()
        session.finishReading()
        logProcessFailure("OpenAdapt capture exited without record.stop", session: session)
        activeCapture = nil
    }

    private func failure(_ message: String) -> GuestCommandResponse {
        GuestCommandResponse(ok: false, message: message)
    }

    private func logProcessFailure(_ prefix: String, session: CaptureSession) {
        logGuestOnly(
            "\(prefix) (status \(session.process.terminationStatus)): " +
            session.output.stderrString
        )
    }

    private func logGuestOnly(_ message: String) {
        FileHandle.standardError.write(Data("OPNDRMGuest: \(message)\n".utf8))
    }

    private static func preparePrivateDirectory(_ directory: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw EngineError.invalidRecordingsDirectory }
            let values = try directory.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw EngineError.invalidRecordingsDirectory }
        } else {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }

    private static func isValidRecordingName(_ name: String) -> Bool {
        guard !name.isEmpty, name.utf8.count <= 128 else { return false }
        return name.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isRegularNonSymlinkFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ) else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func artifactMetadata(at directory: URL) -> (size: Int64, latestModification: Date) {
        var size: Int64 = 0
        var latest = (try? directory.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date(timeIntervalSince1970: 0)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else { return (size, latest) }

        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else { continue }
            let fileSize = Int64(values.fileSize ?? 0)
            size = size > Int64.max - fileSize ? Int64.max : size + fileSize
            if let modified = values.contentModificationDate, modified > latest {
                latest = modified
            }
        }
        return (size, latest)
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

public enum EngineError: Error {
    case invalidOpenAdaptExecutable
    case invalidRecordingsDirectory
}

private final class CaptureSession {
    let name: String
    let artifactDirectory: URL
    let process: Process
    let output: ProcessOutput
    let stdoutPipe: Pipe
    let stderrPipe: Pipe

    init(
        name: String,
        artifactDirectory: URL,
        process: Process,
        output: ProcessOutput,
        stdoutPipe: Pipe,
        stderrPipe: Pipe
    ) {
        self.name = name
        self.artifactDirectory = artifactDirectory
        self.process = process
        self.output = output
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
    }

    func finishReading() {
        output.stopDraining(stdoutPipe, asStandardError: false)
        output.stopDraining(stderrPipe, asStandardError: true)
    }
}

private final class ProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()
    private let maximumBytes = 64 * 1024

    var stdoutString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: stdoutData, encoding: .utf8) ?? ""
    }

    var stderrString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: stderrData, encoding: .utf8) ?? ""
    }

    func drain(_ pipe: Pipe, asStandardError: Bool) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.append(data, asStandardError: asStandardError)
        }
    }

    func stopDraining(_ pipe: Pipe, asStandardError: Bool) {
        pipe.fileHandleForReading.readabilityHandler = nil
        let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remainder.isEmpty {
            append(remainder, asStandardError: asStandardError)
        }
        pipe.fileHandleForReading.closeFile()
    }

    private func append(_ data: Data, asStandardError: Bool) {
        lock.lock(); defer { lock.unlock() }
        if asStandardError {
            appendBounded(data, to: &stderrData)
        } else {
            appendBounded(data, to: &stdoutData)
        }
    }

    private func appendBounded(_ data: Data, to destination: inout Data) {
        guard destination.count < maximumBytes else { return }
        destination.append(data.prefix(maximumBytes - destination.count))
    }
}

private struct CommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
