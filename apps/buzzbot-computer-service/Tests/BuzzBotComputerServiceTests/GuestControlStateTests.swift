@testable import BuzzBotComputerService
import XCTest

final class GuestControlStateTests: XCTestCase {
    func testRecordIsUnmistakablyUnavailableBeforeGuestConfirmation() {
        let state = GuestControlState(
            readiness: .unconfirmed,
            clientConfigured: true,
            commandPending: false,
            isRecording: false
        )

        XCTAssertFalse(state.recordEnabled)
        XCTAssertEqual(state.recordTitle, "Record Unavailable")
        XCTAssertTrue(state.recordHelp.contains("Waiting for the guest helper"))
        XCTAssertTrue(state.guestCheckEnabled)
    }

    func testConfiguredSocketDoesNotCountAsGuestReadiness() {
        let state = GuestControlState(
            readiness: .unavailable("Guest socket connection timed out."),
            clientConfigured: true,
            commandPending: false,
            isRecording: false
        )

        XCTAssertFalse(state.recordEnabled)
        XCTAssertFalse(state.guestActionsEnabled)
        XCTAssertEqual(state.recordHelp, "Guest socket connection timed out.")
    }

    func testConfirmedReadinessEnablesRecordAndUsesTruthfulLabel() {
        let state = GuestControlState(
            readiness: .ready,
            clientConfigured: true,
            commandPending: false,
            isRecording: false
        )

        XCTAssertTrue(state.recordEnabled)
        XCTAssertEqual(state.recordTitle, "Record")
    }

    func testPendingCommandDisablesAllGuestActions() {
        let state = GuestControlState(
            readiness: .ready,
            clientConfigured: true,
            commandPending: true,
            isRecording: false
        )

        XCTAssertFalse(state.recordEnabled)
        XCTAssertFalse(state.guestCheckEnabled)
        XCTAssertFalse(state.guestActionsEnabled)
        XCTAssertEqual(state.recordTitle, "Record Unavailable")
    }

    func testGuestCheckDoesNotClaimToRefreshDisplay() {
        let state = GuestControlState(
            readiness: .ready,
            clientConfigured: true,
            commandPending: false,
            isRecording: false
        )

        XCTAssertEqual(state.guestCheckTitle, "Check Guest")
        XCTAssertTrue(state.guestCheckHelp.contains("does not refresh or repair the VM display"))
    }

    func testConfirmedRecordingOffersStopOnlyWhileReady() {
        let ready = GuestControlState(
            readiness: .ready,
            clientConfigured: true,
            commandPending: false,
            isRecording: true
        )
        let disconnected = GuestControlState(
            readiness: .unavailable("Disconnected"),
            clientConfigured: true,
            commandPending: false,
            isRecording: true
        )

        XCTAssertEqual(ready.recordTitle, "Stop")
        XCTAssertTrue(ready.recordEnabled)
        XCTAssertEqual(disconnected.recordTitle, "Record Unavailable")
        XCTAssertFalse(disconnected.recordEnabled)
    }
}
