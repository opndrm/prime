import BuzzBotProtocol
import XCTest

/// Unit tests for the production GuestCommand JSON codec shared by host and guest.

// MARK: - Tests

final class GuestCommandCodecTests: XCTestCase {

    // MARK: - Request encoding

    func testEncodeRequestEndsWithNewline() throws {
        let request = GuestCommandRequest(action: .status)
        let data = try GuestCommandCodec.encode(request)

        // Must end with 0x0A (newline)
        XCTAssertEqual(data.last, GuestCommandCodec.delimiter)
    }

    func testEncodeRequestProducesValidJSON() throws {
        let request = GuestCommandRequest(action: .recordStart, name: "rec-001", video: true, audio: false)
        let data = try GuestCommandCodec.encode(request)

        // Strip trailing newline and parse JSON
        let jsonData = data.dropLast()
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        XCTAssertEqual(json?["action"] as? String, "record.start")
        XCTAssertEqual(json?["name"] as? String, "rec-001")
        XCTAssertEqual(json?["video"] as? Bool, true)
        XCTAssertEqual(json?["audio"] as? Bool, false)
    }

    // MARK: - Response encoding/decoding

    func testEncodeResponseEndsWithNewline() throws {
        let response = GuestCommandResponse(ok: true, message: "ok")
        let data = try GuestCommandCodec.encode(response)
        XCTAssertEqual(data.last, GuestCommandCodec.delimiter)
    }

    func testDecodeResponseSimple() throws {
        let response = GuestCommandResponse(ok: true, message: "guest helper ready", guestVersion: "1.0.0")
        let encoded = try GuestCommandCodec.encode(response)
        let (decoded, remainder) = try GuestCommandCodec.decodeResponse(from: encoded)

        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.message, "guest helper ready")
        XCTAssertEqual(decoded.guestVersion, "1.0.0")
        XCTAssertTrue(remainder.isEmpty)
    }

    func testDecodeResponseWithRecordings() throws {
        let recordings = [
            GuestRecordingInfo(name: "rec-1", date: "2024-01-01", size: 1024),
            GuestRecordingInfo(name: "rec-2", date: "2024-01-02", size: 2048),
        ]
        let response = GuestCommandResponse(ok: true, message: "2 recordings", recordings: recordings)
        let encoded = try GuestCommandCodec.encode(response)
        let (decoded, _) = try GuestCommandCodec.decodeResponse(from: encoded)

        XCTAssertEqual(decoded.recordings?.count, 2)
        XCTAssertEqual(decoded.recordings?[0].name, "rec-1")
        XCTAssertEqual(decoded.recordings?[1].size, 2048)
    }

    // MARK: - Round-trip for all actions

    func testRoundTripAllActions() throws {
        let actions: [GuestCommandAction] = [.status, .recordStart, .recordStop, .recordingsList, .recordingPlay]
        for action in actions {
            let request = GuestCommandRequest(action: action, name: "test-rec")
            let encoded = try GuestCommandCodec.encode(request)
            let (decoded, _) = try GuestCommandCodec.decodeRequest(from: encoded)
            XCTAssertEqual(decoded.action, action)
            XCTAssertEqual(decoded.name, "test-rec")
        }
    }

    // MARK: - Error cases

    func testDecodeIncompleteThrows() {
        let incomplete = Data("{\"ok\":true,\"message\":\"hi\"".utf8) // no newline
        XCTAssertThrowsError(try GuestCommandCodec.decodeResponse(from: incomplete)) { error in
            XCTAssertEqual(error as? GuestCommandCodecError, GuestCommandCodecError.incompleteMessage)
        }
    }

    func testDecodeInvalidJSONThrows() {
        let bad = Data("not-json\n".utf8)
        XCTAssertThrowsError(try GuestCommandCodec.decodeResponse(from: bad)) { error in
            XCTAssertEqual(error as? GuestCommandCodecError, GuestCommandCodecError.invalidJSON)
        }
    }

    func testDecodeResponseWithRemainder() throws {
        let response = GuestCommandResponse(ok: true, message: "ok")
        let encoded = try GuestCommandCodec.encode(response)
        // Append extra bytes after the newline
        var combined = encoded
        combined.append(Data("extra".utf8))

        let (decoded, remainder) = try GuestCommandCodec.decodeResponse(from: combined)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(String(data: remainder, encoding: .utf8), "extra")
    }
}