import AppKit
import Foundation

/// Tiny OPNDRM-native chat window for one named agent.
/// Handy is the speech input path: focus the input field, press Handy's global
/// shortcut, and Handy pastes the transcript into this field.
@MainActor
final class OPNDRMAgentChatWindowController: NSWindowController, NSTextFieldDelegate {
    private let holder: OPNDRMAgentHarnessHolder
    private let transcriptView = NSTextView()
    private let inputField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")

    init(holder: OPNDRMAgentHarnessHolder) {
        self.holder = holder
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = holder.displayTitle
        window.minSize = NSSize(width: 420, height: 420)
        super.init(window: window)
        setupUI()
        refreshTranscript()
    }

    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        guard let window else { return }
        let root = NSView(frame: window.contentView?.bounds ?? window.frame)
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "\(holder.displayTitle)  →  \(holder.vmName)")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Speak with Handy or type. This agent is bound to one VM only.")
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(subtitle)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.font = NSFont.systemFont(ofSize: 13)
        transcriptView.string = ""
        scrollView.documentView = transcriptView
        root.addSubview(scrollView)

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(statusLabel)

        inputField.placeholderString = "Type here, or click Handy and speak…"
        inputField.delegate = self
        inputField.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(inputField)

        let handyButton = NSButton(title: "🎙 Handy", target: self, action: #selector(handyClicked))
        handyButton.bezelStyle = .rounded
        handyButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(handyButton)

        let sendButton = NSButton(title: "Send", target: self, action: #selector(sendClicked))
        sendButton.keyEquivalent = "\r"
        sendButton.bezelStyle = .rounded
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sendButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            subtitle.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -8),

            inputField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            inputField.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            inputField.trailingAnchor.constraint(equalTo: handyButton.leadingAnchor, constant: -8),

            handyButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            handyButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
        ])

        window.contentView = root
    }

    func refreshTranscript() {
        let text = holder.transcriptText()
        transcriptView.string = text.isEmpty
            ? "Say hi to \(holder.displayTitle). Handy can paste speech into the input below."
            : text
        transcriptView.scrollToEndOfDocument(nil)
        statusLabel.stringValue = holder.statusText
    }

    @objc private func sendClicked() {
        let message = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        do {
            let chatURL = try holder.appendUserMessage(message)
            inputField.stringValue = ""
            statusLabel.stringValue = "Sent to \(holder.displayTitle). Chat bridge: \(chatURL.path)"
            refreshTranscript()
        } catch {
            statusLabel.stringValue = "Could not send: \(error.localizedDescription)"
        }
    }

    @objc private func handyClicked() {
        let handyURL = URL(fileURLWithPath: "/Applications/Handy.app")
        if FileManager.default.fileExists(atPath: handyURL.path) {
            NSWorkspace.shared.open(handyURL)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(inputField)
        statusLabel.stringValue = "Handy ready: press its shortcut, speak, stop recording, then Send."
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let movement = obj.userInfo?["NSTextMovement"] as? Int,
           movement == NSReturnTextMovement {
            sendClicked()
        }
    }
}
