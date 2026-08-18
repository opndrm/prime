import AppKit
import SwiftUI

@MainActor
@Observable
final class ContainerPresentationState {
    let provider = "Apple Container · local"
    let lifecycle = "Unassigned"
    var viewer = "Unavailable"
    let record = "Unavailable"
    var detail = "No task is attached. No virtual machine, live desktop, recording, or remote connection has been started."
    var proofFrame: NSImage?

    func applyViewOnlyFrame(_ frame: NSImage) {
        proofFrame = frame
        viewer = "Watch-only"
        detail = "A local, read-only visual proof frame is connected. It accepts no keyboard, mouse, clipboard, file, terminal, or recording input."
    }

    func markLiveViewUnavailable() {
        guard proofFrame == nil else { return }
        viewer = "Unavailable"
        detail = "No task is attached. No virtual machine, live desktop, recording, or remote connection has been started."
    }
}
