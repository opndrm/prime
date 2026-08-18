import AppKit
import SwiftUI

@main
struct BuzzContainerWindowApp: App {
    @NSApplicationDelegateAdaptor(BuzzContainerWindowDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class BuzzContainerWindowDelegate: NSObject, NSApplicationDelegate {
    private var controller: BuzzContainerPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = BuzzContainerPanelController()
        self.controller = controller
        controller.showOverlay()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
