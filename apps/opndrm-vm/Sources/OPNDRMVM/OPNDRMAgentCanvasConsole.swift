import AppKit
import Foundation

/// OPNDRM-minimal agent creator for one VM.
///
/// The VM is still the real Apple Virtualization visualizer. This view is the
/// calm product surface placed over the canvas while an agent is being created:
/// profile on the left, chat in the middle, settings/screen on the right.
/// Prime/JCode stay hidden behind the named agent.
@MainActor
final class OPNDRMAgentCanvasConsoleView: NSView, NSTextFieldDelegate {
    var onStartRequested: ((String, OPNDRMAgentHarnessHolder.Kind, String, String, String) -> OPNDRMAgentHarnessHolder?)?
    var onHideRequested: (() -> Void)?

    private var vmName = ""
    private var holder: OPNDRMAgentHarnessHolder?
    private var didCreateAgent = false
    private var cursorTrackingArea: NSTrackingArea?

    private let agentRowLabel = NSTextField(labelWithString: "")
    private let renameField = NSTextField()
    private let vmStatusLabel = NSTextField(labelWithString: "")
    private let transcriptView = NSTextView()
    private let messageField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let avatarLabel = NSTextField(labelWithString: "🧭")
    private let nameField = NSTextField()
    private let titleField = NSTextField()
    private let descriptionText = NSTextView()
    private let engineControl = NSSegmentedControl(labels: ["Prime Agent", "JCode"], trackingMode: .selectOne, target: nil, action: nil)
    private let createButton = NSButton(title: "Create Agent", target: nil, action: nil)
    private let screenCard = NSView()
    private var previewView: NSView?
    private let handyButton = NSButton(title: "🎙", target: nil, action: nil)
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let showVMButton = NSButton(title: "Show VM", target: nil, action: nil)
    private let teachButton = NSButton(title: "Teach a task", target: nil, action: nil)

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        showHostCursor()
    }

    override func mouseEntered(with event: NSEvent) {
        showHostCursor()
    }

    override func mouseMoved(with event: NSEvent) {
        showHostCursor()
    }

    override func mouseExited(with event: NSEvent) {
        showHostCursor()
    }

    private func showHostCursor() {
        NSCursor.unhide()
        NSCursor.arrow.set()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0 else { return nil }
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    override func mouseDown(with event: NSEvent) {
        showHostCursor()
        super.mouseDown(with: event)
    }

    func configure(vmName: String, existingHolder: OPNDRMAgentHarnessHolder? = nil) {
        self.vmName = vmName
        self.holder = existingHolder
        self.didCreateAgent = existingHolder != nil
        isHidden = false
        window?.acceptsMouseMovedEvents = true
        showHostCursor()

        if let existingHolder {
            nameField.stringValue = existingHolder.agentName
            avatarLabel.stringValue = existingHolder.emoji
            engineControl.selectedSegment = existingHolder.kind == .prime ? 0 : 1
            transcriptView.string = existingHolder.transcriptText().isEmpty
                ? initialTranscript(agentName: existingHolder.agentName)
                : existingHolder.transcriptText()
        } else {
            resetDraft()
        }
        updateLabels()
        updateMode()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self.messageField)
        }
    }

    func setStatus(_ status: String) {
        statusLabel.stringValue = status
    }

    func refreshTranscript() {
        guard let holder else { return }
        let text = holder.transcriptText()
        transcriptView.string = text.isEmpty ? initialTranscript(agentName: holder.agentName) : text
        transcriptView.scrollToEndOfDocument(nil)
        statusLabel.stringValue = holder.statusText
        didCreateAgent = true
        updateMode()
    }

    func setPreviewView(_ view: NSView?) {
        // Deliberately no-op: the real Apple Virtualization visualizer must stay
        // in the main VM canvas. Do not move it into a decorative card.
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.zPosition = 20

        // Left agent rail.
        let rail = NSView()
        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.wantsLayer = true
        rail.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
        addSubview(rail)

        let railTitle = NSTextField(labelWithString: "Agents")
        railTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        railTitle.textColor = .secondaryLabelColor
        railTitle.translatesAutoresizingMaskIntoConstraints = false
        rail.addSubview(railTitle)

        let agentRow = NSView()
        agentRow.translatesAutoresizingMaskIntoConstraints = false
        agentRow.wantsLayer = true
        agentRow.layer?.cornerRadius = 9
        agentRow.layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
        rail.addSubview(agentRow)

        agentRowLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        agentRowLabel.textColor = .labelColor
        agentRowLabel.translatesAutoresizingMaskIntoConstraints = false
        agentRow.addSubview(agentRowLabel)

        renameField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        renameField.textColor = .labelColor
        renameField.backgroundColor = .clear
        renameField.isBordered = false
        renameField.isHidden = true
        renameField.delegate = self
        renameField.translatesAutoresizingMaskIntoConstraints = false
        agentRow.addSubview(renameField)

        let renameGesture = NSClickGestureRecognizer(target: self, action: #selector(beginInlineRename))
        renameGesture.numberOfClicksRequired = 2
        agentRow.addGestureRecognizer(renameGesture)

        vmStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        vmStatusLabel.textColor = .secondaryLabelColor
        vmStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        rail.addSubview(vmStatusLabel)

        // Center chat area.
        let center = OPNDRMClickThroughView()
        center.translatesAutoresizingMaskIntoConstraints = false
        center.wantsLayer = true
        center.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(center)

        let topBar = OPNDRMClickThroughView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.wantsLayer = true
        topBar.layer?.backgroundColor = NSColor.clear.cgColor
        center.addSubview(topBar)

        let topTitle = NSTextField(labelWithString: "New Agent")
        topTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        topTitle.textColor = .labelColor
        topTitle.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(topTitle)

        showVMButton.target = self
        showVMButton.action = #selector(showVMClicked)
        showVMButton.bezelStyle = .rounded
        showVMButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(showVMButton)

        teachButton.target = self
        teachButton.action = #selector(teachClicked)
        teachButton.bezelStyle = .rounded
        teachButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(teachButton)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .clear
        scrollView.isHidden = true
        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.font = NSFont.systemFont(ofSize: 14)
        transcriptView.textColor = NSColor(calibratedWhite: 0.9, alpha: 1)
        transcriptView.backgroundColor = .clear
        transcriptView.textContainerInset = NSSize(width: 24, height: 24)
        scrollView.documentView = transcriptView
        center.addSubview(scrollView)

        let composer = NSView()
        composer.translatesAutoresizingMaskIntoConstraints = false
        composer.wantsLayer = true
        composer.layer?.cornerRadius = 16
        composer.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.92).cgColor
        center.addSubview(composer)

        messageField.placeholderString = "Message your agent"
        messageField.isBordered = false
        messageField.backgroundColor = .clear
        messageField.textColor = .labelColor
        messageField.font = NSFont.systemFont(ofSize: 14)
        messageField.delegate = self
        messageField.translatesAutoresizingMaskIntoConstraints = false
        composer.addSubview(messageField)

        handyButton.target = self
        handyButton.action = #selector(handyClicked)
        handyButton.bezelStyle = .circular
        handyButton.translatesAutoresizingMaskIntoConstraints = false
        composer.addSubview(handyButton)

        sendButton.target = self
        sendButton.action = #selector(sendClicked)
        sendButton.keyEquivalent = "\r"
        sendButton.bezelStyle = .rounded
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        composer.addSubview(sendButton)

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        center.addSubview(statusLabel)

        // Right inspector / screen card.
        let inspector = NSView()
        inspector.translatesAutoresizingMaskIntoConstraints = false
        inspector.wantsLayer = true
        inspector.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
        addSubview(inspector)

        let settingsLabel = NSTextField(labelWithString: "Settings")
        settingsLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        settingsLabel.textColor = .labelColor
        settingsLabel.translatesAutoresizingMaskIntoConstraints = false
        inspector.addSubview(settingsLabel)

        avatarLabel.font = NSFont.systemFont(ofSize: 36, weight: .regular)
        avatarLabel.alignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        inspector.addSubview(avatarLabel)

        let nameLabel = fieldLabel("Name")
        inspector.addSubview(nameLabel)
        nameField.placeholderString = "First Mate"
        nameField.delegate = self
        nameField.translatesAutoresizingMaskIntoConstraints = false
        inspector.addSubview(nameField)

        let titleLabel = fieldLabel("Title")
        inspector.addSubview(titleLabel)
        titleField.placeholderString = "What this agent does"
        titleField.translatesAutoresizingMaskIntoConstraints = false
        inspector.addSubview(titleField)

        let descriptionLabel = fieldLabel("Description")
        inspector.addSubview(descriptionLabel)
        let descriptionScroll = NSScrollView()
        descriptionScroll.translatesAutoresizingMaskIntoConstraints = false
        descriptionScroll.hasVerticalScroller = true
        descriptionScroll.drawsBackground = false
        descriptionText.font = NSFont.systemFont(ofSize: 12)
        descriptionText.textColor = .labelColor
        descriptionText.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        descriptionText.textContainerInset = NSSize(width: 8, height: 8)
        descriptionScroll.documentView = descriptionText
        inspector.addSubview(descriptionScroll)

        let engineLabel = fieldLabel("Engine")
        inspector.addSubview(engineLabel)
        engineControl.selectedSegment = 1
        engineControl.translatesAutoresizingMaskIntoConstraints = false
        inspector.addSubview(engineControl)

        createButton.target = self
        createButton.action = #selector(createClicked)
        createButton.bezelStyle = .rounded
        createButton.translatesAutoresizingMaskIntoConstraints = false
        inspector.addSubview(createButton)

        screenCard.translatesAutoresizingMaskIntoConstraints = false
        screenCard.wantsLayer = true
        screenCard.layer?.cornerRadius = 10
        screenCard.layer?.masksToBounds = true
        screenCard.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1).cgColor
        screenCard.isHidden = true
        inspector.addSubview(screenCard)

        let screenIcon = NSTextField(labelWithString: "▱")
        screenIcon.font = NSFont.monospacedSystemFont(ofSize: 30, weight: .regular)
        screenIcon.textColor = .secondaryLabelColor
        screenIcon.alignment = .center
        screenIcon.translatesAutoresizingMaskIntoConstraints = false
        screenCard.addSubview(screenIcon)

        let screenLabel = NSTextField(labelWithString: "VM visualizer is live behind this setup")
        screenLabel.font = NSFont.systemFont(ofSize: 11)
        screenLabel.textColor = .secondaryLabelColor
        screenLabel.alignment = .center
        screenLabel.lineBreakMode = .byWordWrapping
        screenLabel.translatesAutoresizingMaskIntoConstraints = false
        screenCard.addSubview(screenLabel)

        NSLayoutConstraint.activate([
            rail.topAnchor.constraint(equalTo: topAnchor),
            rail.bottomAnchor.constraint(equalTo: bottomAnchor),
            rail.leadingAnchor.constraint(equalTo: leadingAnchor),
            rail.widthAnchor.constraint(equalToConstant: 220),

            railTitle.topAnchor.constraint(equalTo: rail.topAnchor, constant: 18),
            railTitle.leadingAnchor.constraint(equalTo: rail.leadingAnchor, constant: 16),
            railTitle.trailingAnchor.constraint(equalTo: rail.trailingAnchor, constant: -16),

            agentRow.topAnchor.constraint(equalTo: railTitle.bottomAnchor, constant: 14),
            agentRow.leadingAnchor.constraint(equalTo: rail.leadingAnchor, constant: 12),
            agentRow.trailingAnchor.constraint(equalTo: rail.trailingAnchor, constant: -12),
            agentRow.heightAnchor.constraint(equalToConstant: 44),

            agentRowLabel.leadingAnchor.constraint(equalTo: agentRow.leadingAnchor, constant: 12),
            agentRowLabel.trailingAnchor.constraint(equalTo: agentRow.trailingAnchor, constant: -12),
            agentRowLabel.centerYAnchor.constraint(equalTo: agentRow.centerYAnchor),

            renameField.leadingAnchor.constraint(equalTo: agentRow.leadingAnchor, constant: 44),
            renameField.trailingAnchor.constraint(equalTo: agentRow.trailingAnchor, constant: -12),
            renameField.centerYAnchor.constraint(equalTo: agentRow.centerYAnchor),

            vmStatusLabel.leadingAnchor.constraint(equalTo: rail.leadingAnchor, constant: 16),
            vmStatusLabel.trailingAnchor.constraint(equalTo: rail.trailingAnchor, constant: -16),
            vmStatusLabel.bottomAnchor.constraint(equalTo: rail.bottomAnchor, constant: -22),

            inspector.topAnchor.constraint(equalTo: topAnchor),
            inspector.bottomAnchor.constraint(equalTo: bottomAnchor),
            inspector.trailingAnchor.constraint(equalTo: trailingAnchor),
            inspector.widthAnchor.constraint(equalToConstant: 300),

            center.topAnchor.constraint(equalTo: topAnchor),
            center.bottomAnchor.constraint(equalTo: bottomAnchor),
            center.leadingAnchor.constraint(equalTo: rail.trailingAnchor),
            center.trailingAnchor.constraint(equalTo: inspector.leadingAnchor),

            topBar.topAnchor.constraint(equalTo: center.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: center.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: center.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 46),

            topTitle.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 18),
            topTitle.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            showVMButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            showVMButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            teachButton.trailingAnchor.constraint(equalTo: showVMButton.leadingAnchor, constant: -8),
            teachButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: center.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: center.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -16),

            composer.leadingAnchor.constraint(equalTo: center.leadingAnchor, constant: 70),
            composer.trailingAnchor.constraint(equalTo: center.trailingAnchor, constant: -70),
            composer.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),
            composer.heightAnchor.constraint(equalToConstant: 72),

            messageField.leadingAnchor.constraint(equalTo: composer.leadingAnchor, constant: 16),
            messageField.trailingAnchor.constraint(equalTo: handyButton.leadingAnchor, constant: -10),
            messageField.topAnchor.constraint(equalTo: composer.topAnchor, constant: 12),
            messageField.heightAnchor.constraint(equalToConstant: 24),

            handyButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            handyButton.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -12),
            handyButton.widthAnchor.constraint(equalToConstant: 28),
            handyButton.heightAnchor.constraint(equalToConstant: 28),

            sendButton.trailingAnchor.constraint(equalTo: composer.trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: composer.leadingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: composer.trailingAnchor, constant: -4),
            statusLabel.bottomAnchor.constraint(equalTo: center.bottomAnchor, constant: -14),

            settingsLabel.topAnchor.constraint(equalTo: inspector.topAnchor, constant: 18),
            settingsLabel.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),

            avatarLabel.topAnchor.constraint(equalTo: settingsLabel.bottomAnchor, constant: 16),
            avatarLabel.centerXAnchor.constraint(equalTo: inspector.centerXAnchor),
            avatarLabel.widthAnchor.constraint(equalToConstant: 70),
            avatarLabel.heightAnchor.constraint(equalToConstant: 46),

            nameLabel.topAnchor.constraint(equalTo: avatarLabel.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            nameField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            nameField.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            nameField.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -18),

            titleLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            titleField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            titleField.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            titleField.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -18),

            descriptionLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 14),
            descriptionLabel.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            descriptionScroll.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 5),
            descriptionScroll.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            descriptionScroll.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -18),
            descriptionScroll.heightAnchor.constraint(equalToConstant: 78),

            engineLabel.topAnchor.constraint(equalTo: descriptionScroll.bottomAnchor, constant: 14),
            engineLabel.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            engineControl.topAnchor.constraint(equalTo: engineLabel.bottomAnchor, constant: 6),
            engineControl.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            engineControl.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -18),

            createButton.topAnchor.constraint(equalTo: engineControl.bottomAnchor, constant: 14),
            createButton.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            createButton.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -18),

            screenCard.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 18),
            screenCard.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -18),
            screenCard.bottomAnchor.constraint(equalTo: inspector.bottomAnchor, constant: -22),
            screenCard.heightAnchor.constraint(equalToConstant: 145),

            screenIcon.centerXAnchor.constraint(equalTo: screenCard.centerXAnchor),
            screenIcon.centerYAnchor.constraint(equalTo: screenCard.centerYAnchor, constant: -12),
            screenLabel.leadingAnchor.constraint(equalTo: screenCard.leadingAnchor, constant: 14),
            screenLabel.trailingAnchor.constraint(equalTo: screenCard.trailingAnchor, constant: -14),
            screenLabel.topAnchor.constraint(equalTo: screenIcon.bottomAnchor, constant: 8),
        ])

        resetDraft()
    }

    private func fieldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func resetDraft() {
        didCreateAgent = false
        holder = nil
        renameField.isHidden = true
        agentRowLabel.isHidden = false
        avatarLabel.stringValue = "🧭"
        nameField.stringValue = "First Mate"
        titleField.stringValue = "VM copilot"
        descriptionText.string = "Help me operate this VM safely. Automate inside the VM when possible. Ask before destructive changes."
        engineControl.selectedSegment = 1
        transcriptView.string = """
        I’m awake. Pick a name, then send a message.

        The VM gets the real screen. I’ll keep the chat short, useful, and honest.
        Tiny jokes allowed; fake magic banned.
        """
        statusLabel.stringValue = "Ready. Send a message and I’ll create the agent automatically."
        updateLabels()
        updateMode()
    }

    private func updateLabels() {
        let display = displayName()
        agentRowLabel.stringValue = "\(avatarLabel.stringValue)  \(display)"
        vmStatusLabel.stringValue = vmName.isEmpty ? "No VM selected" : "Assigned VM: \(vmName)"
        messageField.placeholderString = "Message \(display)"
    }

    private func applyProfileEdits() {
        updateLabels()
        holder?.updateProfile(
            agentName: displayName(),
            emoji: avatarLabel.stringValue,
            instructions: instructions()
        )
        refreshTranscript()
    }


    private func updateMode() {
        createButton.title = didCreateAgent ? "Agent Created" : "Create Agent"
        createButton.isEnabled = !didCreateAgent
    }

    private func displayName() -> String {
        let raw = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "First Mate" : raw
    }

    private func selectedKind() -> OPNDRMAgentHarnessHolder.Kind {
        engineControl.selectedSegment == 1 ? .jcode : .prime
    }

    private func instructions() -> String {
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = descriptionText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        Agent title: \(title.isEmpty ? "VM copilot" : title)
        User description: \(description.isEmpty ? "Help operate this VM safely." : description)

        Keep the conversation simple, curious, and stress-free. Work only inside your assigned VM. Keep output minimal but informative. Never ghost the user; give honest status if blocked. Do not show Prime Agent or JCode terminal output to the user.
        """
    }

    @discardableResult
    private func ensureAgentCreated() -> OPNDRMAgentHarnessHolder? {
        if let holder { return holder }
        let name = displayName()
        let emoji = avatarLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🧭" : avatarLabel.stringValue
        let kind = selectedKind()
        statusLabel.stringValue = "Creating \(emoji) \(name) with \(kind.displayName)…"
        transcriptView.string = """
        \(emoji) \(name)
        \(titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))

        Binding to \(vmName)…
        Starting \(kind.displayName)…
        I’ll report honestly if the bridge blocks. No smoke machine.
        """
        let created = onStartRequested?(vmName, kind, name, emoji, instructions())
        holder = created
        didCreateAgent = created != nil
        updateLabels()
        updateMode()
        refreshTranscript()
        return created
    }

    private func initialTranscript(agentName: String) -> String {
        """
        🧭 \(agentName) is ready.
        VM: \(vmName) • Engine: \(selectedKind().displayName)

        What should we try first?
        """
    }

    @objc private func beginInlineRename() {
        renameField.stringValue = displayName()
        renameField.isHidden = false
        agentRowLabel.isHidden = true
        window?.makeFirstResponder(renameField)
        renameField.currentEditor()?.selectAll(nil)
    }

    private func commitInlineRename() {
        let newName = renameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty {
            nameField.stringValue = newName
        }
        renameField.isHidden = true
        agentRowLabel.isHidden = false
        applyProfileEdits()
        statusLabel.stringValue = "Renamed agent to \(displayName())."
    }

    @objc private func createClicked() {
        _ = ensureAgentCreated()
        window?.makeFirstResponder(messageField)
    }

    @objc private func sendClicked() {
        let message = messageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard let holder = ensureAgentCreated() else { return }
        do {
            try holder.appendUserMessage(message)
            messageField.stringValue = ""
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
        window?.makeFirstResponder(messageField)
        statusLabel.stringValue = "Handy ready: press your Handy shortcut, speak, stop recording, then Send."
    }

    @objc private func showVMClicked() {
        alphaValue = 0
        isHidden = true
        onHideRequested?()
    }

    @objc private func teachClicked() {
        statusLabel.stringValue = "Teach mode will record the VM soon. For now, tell the agent what to learn/do."
        window?.makeFirstResponder(messageField)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            if field === renameField {
                commitInlineRename()
                return
            }
            if field === nameField {
                applyProfileEdits()
                if let movement = obj.userInfo?["NSTextMovement"] as? Int,
                   movement == NSReturnTextMovement {
                    window?.makeFirstResponder(messageField)
                }
                return
            }
            if field === messageField,
               let movement = obj.userInfo?["NSTextMovement"] as? Int,
               movement == NSReturnTextMovement {
                sendClicked()
            }
        }
    }
}


@MainActor
private final class OPNDRMClickThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0 else { return nil }
        for subview in subviews.reversed() where !subview.isHidden && subview.alphaValue > 0 {
            let converted = convert(point, to: subview)
            if let hit = subview.hitTest(converted) {
                return hit
            }
        }
        return nil
    }
}
