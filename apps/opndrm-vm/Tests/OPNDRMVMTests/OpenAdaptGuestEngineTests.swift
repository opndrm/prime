import OPNDRMGuestEngine
import OPNDRMProtocol
import Foundation
import XCTest

@MainActor
final class OpenAdaptGuestEngineTests: XCTestCase {
    func testCaptureLifecycleUsesSupportedCLIAndKeepsArtifactsGuestLocal() throws {
        let harness = try EngineHarness(consent: true)
        defer { harness.remove() }

        let start = harness.engine.handle(
            GuestCommandRequest(
                action: .recordStart,
                name: "recording-001",
                video: true,
                audio: false
            )
        )
        XCTAssertTrue(start.ok, start.message)
        XCTAssertEqual(start.message, "guest recording started: recording-001")

        let status = harness.engine.handle(.init(action: .status))
        XCTAssertTrue(status.ok)
        XCTAssertTrue(status.message.contains("recording active"))

        let secondStart = harness.engine.handle(
            .init(action: .recordStart, name: "recording-002")
        )
        XCTAssertFalse(secondStart.ok)

        let stop = harness.engine.handle(.init(action: .recordStop))
        XCTAssertTrue(stop.ok, stop.message)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: harness.recordings
                    .appendingPathComponent("recording-001/recording.db").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: harness.recordings
                    .appendingPathComponent("recording-001/finalized.txt").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: harness.recordings
                    .appendingPathComponent("recording-001/.opndrm-vm-openadapt-complete").path
            )
        )

        let invocations = try harness.invocations()
        XCTAssertEqual(
            invocations.first,
            ["capture", "start", "--name", "recording-001", "--video", "--no-audio"]
        )

        let list = harness.engine.handle(.init(action: .recordingsList))
        XCTAssertTrue(list.ok, list.message)
        XCTAssertEqual(list.recordings?.count, 1)
        XCTAssertEqual(list.recordings?.first?.name, "recording-001")
        XCTAssertGreaterThan(list.recordings?.first?.size ?? 0, 0)
        XCTAssertNotNil(list.recordings?.first?.date)

        let play = harness.engine.handle(
            .init(action: .recordingPlay, name: "recording-001")
        )
        XCTAssertTrue(play.ok, play.message)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: harness.recordings
                    .appendingPathComponent("recording-001/viewer.html").path
            )
        )
        XCTAssertEqual(
            try harness.invocations().last,
            ["capture", "view", "recording-001", "--open"]
        )
    }

    func testGuestConsentDeclineStartsNoProcessAndCreatesNoArtifact() throws {
        let harness = try EngineHarness(consent: false)
        defer { harness.remove() }

        let response = harness.engine.handle(
            .init(action: .recordStart, name: "declined", video: true, audio: false)
        )

        XCTAssertFalse(response.ok)
        XCTAssertEqual(response.message, "guest recording consent was declined")
        XCTAssertEqual(harness.consent.requests, ["declined"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.invocationLog.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: harness.recordings.appendingPathComponent("declined").path
            )
        )
    }

    func testExitedProcessIsNeverClaimedOrListedAsARecording() throws {
        let harness = try EngineHarness(consent: true)
        defer { harness.remove() }
        try harness.replaceExecutable(with: #"""
#!/usr/bin/env python3
import os
import sys
name = sys.argv[sys.argv.index("--name") + 1]
os.mkdir(name)
with open(os.path.join(name, "recording.db"), "wb") as stream:
    stream.write(b"incomplete")
print("Starting capture session: " + name, flush=True)
raise SystemExit(70)
"""#)

        let response = harness.engine.handle(
            .init(action: .recordStart, name: "never-ready", video: true, audio: false)
        )
        XCTAssertFalse(response.ok)
        XCTAssertFalse(response.message.contains("started"))

        let list = harness.engine.handle(.init(action: .recordingsList))
        XCTAssertTrue(list.ok)
        XCTAssertEqual(list.recordings, [])
    }

    func testNamesAreBoundedAndCannotEscapeGuestRecordingRoot() throws {
        let harness = try EngineHarness(consent: true)
        defer { harness.remove() }

        for name in ["../escape", "/tmp/escape", ".hidden", "bad name", String(repeating: "a", count: 129)] {
            let response = harness.engine.handle(
                .init(action: .recordStart, name: name, video: true, audio: false)
            )
            XCTAssertFalse(response.ok, "unexpectedly accepted \(name)")
        }
        XCTAssertTrue(harness.consent.requests.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.invocationLog.path))
    }

    func testListUsesGuestFilesystemMetadataAndIgnoresIncompleteAndSymlinkEntries() throws {
        let harness = try EngineHarness(consent: true)
        defer { harness.remove() }

        let complete = harness.recordings.appendingPathComponent("complete")
        try FileManager.default.createDirectory(at: complete, withIntermediateDirectories: true)
        try Data("database".utf8).write(to: complete.appendingPathComponent("recording.db"))
        try Data(repeating: 7, count: 32).write(to: complete.appendingPathComponent("events.bin"))
        let marker = Data("opndrm-vm-openadapt-capture/v1\n".utf8)
        try marker.write(to: complete.appendingPathComponent(".opndrm-vm-openadapt-complete"))

        let incomplete = harness.recordings.appendingPathComponent("incomplete")
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        try Data("not a capture".utf8).write(to: incomplete.appendingPathComponent("notes.txt"))

        let link = harness.recordings.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: complete)

        let response = harness.engine.handle(.init(action: .recordingsList))

        XCTAssertTrue(response.ok, response.message)
        XCTAssertEqual(response.recordings?.map(\.name), ["complete"])
        XCTAssertEqual(response.recordings?.first?.size, 40 + Int64(marker.count))
    }

    func testReviewRefusesWhileCaptureIsActive() throws {
        let harness = try EngineHarness(consent: true)
        defer {
            _ = harness.engine.handle(.init(action: .recordStop))
            harness.remove()
        }

        let start = harness.engine.handle(
            .init(action: .recordStart, name: "active-review", video: true, audio: false)
        )
        XCTAssertTrue(start.ok, start.message)

        let review = harness.engine.handle(
            .init(action: .recordingPlay, name: "active-review")
        )
        XCTAssertFalse(review.ok)
        XCTAssertEqual(review.message, "stop the active guest recording before review")
    }
}

@MainActor
private final class TestConsent: RecordingConsentProviding {
    let decision: Bool
    private(set) var requests: [String] = []

    init(decision: Bool) {
        self.decision = decision
    }

    func requestConsent(name: String, capturesVideo: Bool, capturesAudio: Bool) -> Bool {
        requests.append(name)
        return decision
    }
}

@MainActor
private final class EngineHarness {
    let root: URL
    let recordings: URL
    let executable: URL
    let invocationLog: URL
    let consent: TestConsent
    let engine: OpenAdaptGuestEngine

    init(consent decision: Bool) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("opndrm-vm-openadapt-tests-\(UUID().uuidString)")
        recordings = root.appendingPathComponent("Recordings")
        executable = root.appendingPathComponent("fake-openadapt")
        invocationLog = recordings.appendingPathComponent("invocations.jsonl")
        consent = TestConsent(decision: decision)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Self.fakeOpenAdapt.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        engine = try OpenAdaptGuestEngine(
            openAdaptExecutable: executable,
            recordingsDirectory: recordings,
            consentProvider: consent,
            startupTimeout: 3,
            stopTimeout: 3,
            commandTimeout: 3
        )
    }

    func invocations() throws -> [[String]] {
        let data = try Data(contentsOf: invocationLog)
        return try String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { line in
                try JSONDecoder().decode([String].self, from: Data(line.utf8))
            }
    }

    func replaceExecutable(with script: String) throws {
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    private static let fakeOpenAdapt = #"""
#!/usr/bin/env python3
import json
import os
import signal
import sys
import time

args = sys.argv[1:]
with open("invocations.jsonl", "a", encoding="utf-8") as stream:
    stream.write(json.dumps(args) + "\n")
    stream.flush()

if args[:2] == ["capture", "start"]:
    name = args[args.index("--name") + 1]
    os.mkdir(name)
    with open(os.path.join(name, "recording.db"), "wb") as stream:
        stream.write(b"real-test-artifact")

    def stop(_signum, _frame):
        with open(os.path.join(name, "finalized.txt"), "w", encoding="utf-8") as stream:
            stream.write("stopped")
        raise SystemExit(0)

    signal.signal(signal.SIGINT, stop)
    print("Starting capture session: " + name, flush=True)
    print("Recording...", flush=True)
    while True:
        time.sleep(0.05)
elif args[:2] == ["capture", "view"]:
    name = args[2]
    with open(os.path.join(name, "viewer.html"), "w", encoding="utf-8") as stream:
        stream.write("<html>guest-local review</html>")
else:
    raise SystemExit(64)
"""#
}
