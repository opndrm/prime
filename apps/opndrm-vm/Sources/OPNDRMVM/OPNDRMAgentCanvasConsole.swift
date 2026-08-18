import AppKit
import Foundation

/// Terminal-style agent surface that appears over the VM canvas after boot.
///
/// This keeps Prime Agent/JCode hidden: the user only chooses an engine once,
/// then talks to First Mate in OPNDRM. Handy is used for speech input by focusing
/// the chat field and letting Handy paste the transcript there.
@MainActor
final class OPNDRMAgentCanvasConsoleView: NSView, NSTextFieldDelegate {
    var onStartRequested: ((String, OPNDRMAgentHarnessHolder.Kind) -> OPNDRMAgentHarnessHolder?)?
    var onHideRequested: (() -> Void)?

    private var vmName = ""
    private var holder: OPNDRMAgentHarnessHolder?

    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let transcriptView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let inputField = NSTextField()
    private let primeButton = NSButton(title: "Prime Agent", target: nil, action: nil)
    private let jcodeButton = NSButton(title: "JCode", target: nil, action: nil)
    private let handyButton = NSButton(title: "🎙 Handy", target: nil, action: nil)
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let showVMButton = NSButton(title: "Show VM", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) { nil }

    func configure(vmName: String, existingHolder: OPNDRMAgentHarnessHolder? = nil) {
        self.vmName = vmName
        self.holder = existingHolder
        isHidden = false
        if existingHolder == nil {
            showChooser()
        } else {
            showChat()
        }
    }

    func setStatus(_ status: String) {
        statusLabel.stringValue = status
    }

    func refreshTranscript() {
        guard let holder else { return }
        let text = holder.transcriptText()
        transcriptView.string = text.isEmpty
            ? "\(holder.displayTitle): I’m ready inside \(holder.vmName). What should I do?"
            : text
        transcriptView.scrollToEndOfDocument(nil)
        statusLabel.stringValue = holder.statusText
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor
        layer?.zPosition = 20

        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 0.96).cgColor
        panel.layer?.cornerRadius = 18
        panel.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.35).cgColor
        panel.layer?.borderWidth = 1
        addSubview(panel)

        titleLabel.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .systemGreen
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        bodyLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = .labelColor
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(bodyLabel)

        primeButton.target = self
        primeButton.action = #selector(primeClicked)
        primeButton.bezelStyle = .rounded
        primeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(primeButton)

        jcodeButton.target = self
        jcodeButton.action = #selector(jcodeClicked)
        jcodeButton.bezelStyle = .rounded
        jcodeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(jcodeButton)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.black.cgColor
        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        transcriptView.textColor = .labelColor
        transcriptView.backgroundColor = .black
        transcriptView.string = ""
        scrollView.documentView = transcriptView
        panel.addSubview(scrollView)

        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(statusLabel)

        inputField.placeholderString = "Talk to First Mate…"
        inputField.delegate = self
        inputField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(inputField)

        handyButton.target = self
        handyButton.action = #selector(handyClicked)
        handyButton.bezelStyle = .rounded
        handyButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(handyButton)

        sendButton.target = self
        sendButton.action = #selector(sendClicked)
        sendButton.keyEquivalent = "\r"
        sendButton.bezelStyle = .rounded
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(sendButton)

        showVMButton.target = self
        showVMButton.action = #selector(showVMClicked)
        showVMButton.bezelStyle = .rounded
        showVMButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(showVMButton)

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.82),
            panel.widthAnchor.constraint(greaterThanOrEqualToConstant: 520),
            panel.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.82),
            panel.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),

            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: showVMButton.leadingAnchor, constant: -12),

            showVMButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            showVMButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),
            bodyLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            bodyLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),

            primeButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 18),
            primeButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),

            jcodeButton.centerYAnchor.constraint(equalTo: primeButton.centerYAnchor),
            jcodeButton.leadingAnchor.constraint(equalTo: primeButton.trailingAnchor, constant: 12),

            scrollView.topAnchor.constraint(equalTo: primeButton.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -8),

            inputField.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            inputField.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -22),
            inputField.trailingAnchor.constraint(equalTo: handyButton.leadingAnchor, constant: -8),

            handyButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            handyButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
        ])

        showChooser()
    }

    private func showChooser() {
        titleLabel.stringValue = "Welcome to OPNDRM VM"
        bodyLabel.stringValue = """
        VM: \(vmName.isEmpty ? "selected VM" : vmName)

        Run this VM with:

        [1] Prime Agent
        [2] JCode

        First Mate will be created automatically and bound to this VM.
        You will only see this simple conversation — no Prime/JCode terminal scroll.
        """
        transcriptView.string = ""
        statusLabel.stringValue = "Choose an engine to begin."
        primeButton.isHidden = false
        jcodeButton.isHidden = false
        inputField.isHidden = true
        handyButton.isHidden = true
        sendButton.isHidden = true
        showVMButton.isHidden = false
    }

    private func showChat() {
        titleLabel.stringValue = "🧭 First Mate"
        bodyLabel.stringValue = "Bound to VM: \(vmName)"
        primeButton.isHidden = true
        jcodeButton.isHidden = true
        inputField.isHidden = false
        handyButton.isHidden = false
        sendButton.isHidden = false
        showVMButton.isHidden = false
        refreshTranscript()
        window?.makeFirstResponder(inputField)
    }

    @objc private func primeClicked() { choose(.prime) }
    @objc private func jcodeClicked() { choose(.jcode) }

    private func choose(_ kind: OPNDRMAgentHarnessHolder.Kind) {
        guard !vmName.isEmpty else { return }
        statusLabel.stringValue = "Starting First Mate with \(kind.displayName)…"
        holder = onStartRequested?(vmName, kind)
        showChat()
    }

    @objc private func sendClicked() {
        let message = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let holder else { return }
        do {
            try holder.appendUserMessage(message)
            inputField.stringValue = ""
            statusLabel.stringValue = "Sent to \(holder.displayTitle)."
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
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(inputField)
        statusLabel.stringValue = "Handy ready: press your Handy shortcut, speak, stop recording, then Send."
    }

    @objc private func showVMClicked() {
        isHidden = true
        onHideRequested?()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let movement = obj.userInfo?["NSTextMovement"] as? Int,
           movement == NSReturnTextMovement {
            sendClicked()
        }
    }
}
