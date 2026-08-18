import Foundation

/// Readiness confirmed by a successful guest-helper status response.
/// A configured virtio socket alone does not prove the helper or OpenAdapt is available.
enum GuestReadiness: Equatable {
    case unconfirmed
    case checking
    case ready
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var unavailableReason: String {
        switch self {
        case .unconfirmed:
            return "Waiting for the guest helper and OpenAdapt readiness check."
        case .checking:
            return "Checking the guest helper and OpenAdapt readiness."
        case .ready:
            return ""
        case .unavailable(let message):
            return message.isEmpty ? "The guest helper or OpenAdapt is unavailable." : message
        }
    }
}

/// Pure presentation policy for the native overlay controls. Keeping this policy
/// independent of AppKit makes the disabled-state contract directly testable.
struct GuestControlState: Equatable {
    let readiness: GuestReadiness
    let clientConfigured: Bool
    let commandPending: Bool
    let isRecording: Bool

    var recordEnabled: Bool {
        clientConfigured && readiness.isReady && !commandPending
    }

    var guestCheckEnabled: Bool {
        clientConfigured && !commandPending
    }

    var guestActionsEnabled: Bool {
        recordEnabled
    }

    var recordTitle: String {
        guard recordEnabled else { return "Record Unavailable" }
        return isRecording ? "Stop" : "Record"
    }

    var recordHelp: String {
        if commandPending { return "A guest command is in progress." }
        if !clientConfigured { return "The guest command connection is not configured." }
        if !readiness.isReady { return readiness.unavailableReason }
        return isRecording ? "Stop the confirmed guest recording." : "Start recording inside the guest with OpenAdapt."
    }

    var guestCheckTitle: String { "Check Guest" }

    var guestCheckHelp: String {
        if commandPending { return "A guest command is in progress." }
        if !clientConfigured { return "The guest command connection is not configured." }
        return "Check guest-helper and OpenAdapt readiness. This does not refresh or repair the VM display."
    }
}
