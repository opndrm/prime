import Foundation

/// JSON wire protocol shared between the host client and the guest helper.
/// All messages are newline-delimited JSON objects with a fixed "action" field.
/// The host always sends a Request; the guest always replies with a Response.
/// Recordings and playback remain inside the guest; the host receives metadata only.

public enum GuestCommandAction: String, Codable, Sendable {
    case status
    case recordStart = "record.start"
    case recordStop = "record.stop"
    case recordingsList = "recordings.list"
    case recordingPlay = "recording.play"
}

// MARK: - Request

public struct GuestCommandRequest: Codable, Sendable {
    public let action: GuestCommandAction
    /// Recording name/id for record.start and recording.play.
    public var name: String?
    /// Convenience for record.start.
    public var video: Bool?
    public var audio: Bool?

    public init(action: GuestCommandAction, name: String? = nil, video: Bool? = nil, audio: Bool? = nil) {
        self.action = action
        self.name = name
        self.video = video
        self.audio = audio
    }
}

// MARK: - Response

public struct GuestRecordingInfo: Codable, Sendable, Equatable {
    public let name: String
    public let date: String
    public let size: Int64

    public init(name: String, date: String, size: Int64) {
        self.name = name
        self.date = date
        self.size = size
    }
}

public struct GuestCommandResponse: Codable, Sendable {
    public let ok: Bool
    /// Human-readable status or error message.
    public let message: String
    /// Populated for recordings.list.
    public let recordings: [GuestRecordingInfo]?
    /// Populated for status.
    public let guestVersion: String?

    public init(ok: Bool, message: String, recordings: [GuestRecordingInfo]? = nil, guestVersion: String? = nil) {
        self.ok = ok
        self.message = message
        self.recordings = recordings
        self.guestVersion = guestVersion
    }
}

// MARK: - Codec

/// Line-delimited JSON codec for GuestCommandRequest / GuestCommandResponse.
public enum GuestCommandCodec {
    /// Delimiter used between framed messages on the socket.
    public static let delimiter: UInt8 = 0x0A // '\n'

    /// Encode a request to a single JSON line terminated by '\n'.
    public static func encode(_ request: GuestCommandRequest) throws -> Data {
        let json = try JSONEncoder().encode(request)
        guard var line = String(data: json, encoding: .utf8) else {
            throw GuestCommandCodecError.invalidEncoding
        }
        line.append("\n")
        guard let data = line.data(using: .utf8) else {
            throw GuestCommandCodecError.invalidEncoding
        }
        return data
    }

    /// Encode a response to a single JSON line terminated by '\n'.
    public static func encode(_ response: GuestCommandResponse) throws -> Data {
        let json = try JSONEncoder().encode(response)
        guard var line = String(data: json, encoding: .utf8) else {
            throw GuestCommandCodecError.invalidEncoding
        }
        line.append("\n")
        guard let data = line.data(using: .utf8) else {
            throw GuestCommandCodecError.invalidEncoding
        }
        return data
    }

    /// Decode the first complete line from a Data buffer, returning the decoded
    /// response and the remaining bytes (if any).
    public static func decodeResponse(from data: Data) throws -> (GuestCommandResponse, Data) {
        guard let newlineIndex = data.firstIndex(of: delimiter) else {
            throw GuestCommandCodecError.incompleteMessage
        }
        let lineData = data.subdata(in: data.startIndex..<newlineIndex)
        let remainder = data.subdata(in: data.index(after: newlineIndex)..<data.endIndex)
        guard let json = String(data: lineData, encoding: .utf8) else {
            throw GuestCommandCodecError.invalidEncoding
        }
        guard let resp = try? JSONDecoder().decode(GuestCommandResponse.self, from: Data(json.utf8)) else {
            throw GuestCommandCodecError.invalidJSON
        }
        return (resp, remainder)
    }

    /// Decode the first complete line from a Data buffer into a request.
    public static func decodeRequest(from data: Data) throws -> (GuestCommandRequest, Data) {
        guard let newlineIndex = data.firstIndex(of: delimiter) else {
            throw GuestCommandCodecError.incompleteMessage
        }
        let lineData = data.subdata(in: data.startIndex..<newlineIndex)
        let remainder = data.subdata(in: data.index(after: newlineIndex)..<data.endIndex)
        guard let json = String(data: lineData, encoding: .utf8) else {
            throw GuestCommandCodecError.invalidEncoding
        }
        guard let req = try? JSONDecoder().decode(GuestCommandRequest.self, from: Data(json.utf8)) else {
            throw GuestCommandCodecError.invalidJSON
        }
        return (req, remainder)
    }
}

public enum GuestCommandCodecError: Error, LocalizedError, Equatable {
    case invalidEncoding
    case incompleteMessage
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "Failed UTF-8 encoding for guest command frame."
        case .incompleteMessage: return "Incomplete message — no newline delimiter found."
        case .invalidJSON: return "Invalid JSON in guest command frame."
        }
    }
}