import AppKit
import Foundation
import Testing
@testable import BuzzContainerWindow

@Test func decoderAcceptsAPPMFrame() throws {
    let image = try UnixFrameReceiver.decodePPM(Data([80, 54, 10, 49, 32, 49, 10, 50, 53, 53, 10, 1, 2, 3]))
    #expect(image.size.width == 1)
    #expect(image.size.height == 1)
}

@Test func decoderRejectsOversizedDimensionsBeforeAllocating() {
    let header = Data("P6\\n99999 1\\n255\\n".utf8)
    #expect(throws: UnixFrameReceiver.FrameError.invalidPPM) {
        _ = try UnixFrameReceiver.decodePPM(header)
    }
}

@Test func decoderDoesNotConsumeTheFirstWhitespacePixel() throws {
    let frame = Data([80, 54, 10, 49, 32, 49, 10, 50, 53, 53, 10, 10, 2, 3])
    let image = try UnixFrameReceiver.decodePPM(frame)
    #expect(image.size == NSSize(width: 1, height: 1))
}

@Test func socketConfigurationIsOptInAndRejectsRelativePaths() {
    #expect(UnixFrameReceiver.Configuration.fromEnvironment([:]) == nil)
    #expect(UnixFrameReceiver.Configuration.fromEnvironment([
        "BUZZ_CONTAINER_VIEW_SOCKET": "relative.sock",
        "BUZZ_CONTAINER_VIEW_TOKEN": "owner-token"
    ]) == nil)
    #expect(UnixFrameReceiver.Configuration.fromEnvironment([
        "BUZZ_CONTAINER_VIEW_SOCKET": "/private/owner/view.sock",
        "BUZZ_CONTAINER_VIEW_TOKEN": "owner-token"
    ]) != nil)
}
