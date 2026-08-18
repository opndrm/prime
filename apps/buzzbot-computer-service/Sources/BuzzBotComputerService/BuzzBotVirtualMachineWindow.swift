import AppKit
import BuzzBotProtocol
import QuartzCore
@preconcurrency import Virtualization

@MainActor
final class BuzzBotVirtualMachineWindowController: NSWindowController, NSWindowDelegate {
    private let controller: VirtualMachineController
    private let virtualMachineView = VZVirtualMachineView()
    private var attachedMachine: VZVirtualMachine?
    private let machineName: String

    // Title bar buttons — styled as clean small pills, not grey boxes
    private let recordButton = NSButton(title: "●", target: nil, action: nil)
    private let refreshButton = NSButton(title: "↻", target: nil, action: nil)
    private var isRecording = false
    private var commandPending = false
    private var redGlowTimer: Timer?

    private enum DrawerState {
        case connecting
        case guestUnavailable(String?)
        case openAdaptMissing(String?)
        case commandFailed(String?)
        case noRecordings
        case recording
        case ready

        var title: String {
            switch self {
            case .connecting: return "Connecting"
            case .guestUnavailable: return "Guest Unavailable"
            case .openAdaptMissing: return "OpenAdapt Missing"
            case .commandFailed: return "Command Failed"
            case .noRecordings: return "No Recordings"
            case .recording: return "Recording"
            case .ready: return "Ready"
            }
        }

        var detail: String? {
            switch self {
            case .guestUnavailable(let message), .openAdaptMissing(let message), .commandFailed(let message):
                return message
            default:
                return nil
            }
        }

        var color: NSColor {
            switch self {
            case .recording: return .systemRed
            case .ready: return .systemGreen
            case .connecting: return .systemOrange
            case .noRecordings: return .secondaryLabelColor
            case .guestUnavailable, .openAdaptMissing, .commandFailed: return .systemYellow
            }
        }
    }

    // Recordings panel — bottom right, collapsible, PERFECT alignment
    private var recordingsPanel: NSView?
    private var recordingsToggle: NSButton?
    private var recordingsExpanded = false
    private var recordingsScrollView: NSScrollView?
    private var recordingsGrid: NSStackView?
    private var recordingsHeightConstraint: NSLayoutConstraint?
    private let recordingsCollapsedHeight: CGFloat = 26
    private let recordingsExpandedHeight: CGFloat = 200
    private var drawerEventMonitor: Any?
    private var recordingRows: [NSView] = []
    private var playButtons: [NSButton] = []
    private var selectedRecordingIndex: Int?
    private var drawerState: DrawerState = .connecting

    // Cached guest recordings (metadata only; files stay in the guest)
    private var cachedRecordings: [GuestRecordingInfo] = []

    init(controller: VirtualMachineController, machineName: String = "") {
        self.controller = controller
        self.machineName = machineName
        NSApplication.shared.setActivationPolicy(.accessory)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = machineName.isEmpty ? "Agent Computer" : machineName
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 640, height: 400)
        panel.contentView?.wantsLayer = true
        super.init(window: panel)
        panel.delegate = self

        // VM view fills entire content — zero padding, zero boxing
        virtualMachineView.translatesAutoresizingMaskIntoConstraints = false
        virtualMachineView.wantsLayer = true
        virtualMachineView.layer?.backgroundColor = NSColor.black.cgColor
        panel.contentView?.addSubview(virtualMachineView)

        if let cv = panel.contentView {
            NSLayoutConstraint.activate([
                virtualMachineView.topAnchor.constraint(equalTo: cv.topAnchor),
                virtualMachineView.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
                virtualMachineView.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                virtualMachineView.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            ])
        }

        // Style title bar buttons as clean pills
        styleTitleBarButton(recordButton, title: "●")
        recordButton.action = #selector(recordButtonClicked)
        recordButton.target = self

        styleTitleBarButton(refreshButton, title: "↻")
        refreshButton.action = #selector(refreshButtonClicked)
        refreshButton.target = self

        if let themeFrame = panel.contentView?.superview {
            themeFrame.addSubview(recordButton, positioned: .above, relativeTo: nil)
            themeFrame.addSubview(refreshButton, positioned: .above, relativeTo: nil)
        }

        buildRecordingsPanel()

        panel.orderOut(nil)

        controller.machineDidStart = { [weak self] machine in
            self?.showVirtualMachine(machine)
        }
    }

    private func styleTitleBarButton(_ button: NSButton, title: String) {
        button.title = title
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 3
        button.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.7).cgColor
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.contentTintColor = NSColor.white
        button.translatesAutoresizingMaskIntoConstraints = true
    }

    required init?(coder: NSCoder) { nil }

    func windowDidUpdate(_ notification: Notification) {
        guard let themeFrame = window?.contentView?.superview else { return }
        let width = themeFrame.bounds.width
        let y: CGFloat = themeFrame.isFlipped ? 3 : themeFrame.bounds.height - 22
        // Keep both controls centered in the top title-bar strip on either frame orientation.
        recordButton.frame = NSRect(x: width - 62, y: y, width: 28, height: 18)
        refreshButton.frame = NSRect(x: width - 92, y: y, width: 26, height: 18)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        collapseRecordings()
        sender.orderOut(nil)
        return false
    }

    func windowWillMiniaturize(_ notification: Notification) {
        collapseRecordings()
        window?.orderOut(nil)
    }

    private func showVirtualMachine(_ machine: VZVirtualMachine) {
        virtualMachineView.virtualMachine = machine
        attachedMachine = machine
        if controller.guestSocketClient == nil {
            setDrawerState(.guestUnavailable("Guest helper connection is not configured"))
        } else {
            updateControlAvailability()
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            NSApp.setActivationPolicy(.accessory)
            self?.window?.makeKeyAndOrderFront(nil)
        }
        window?.level = .floating
    }

    // MARK: - Recordings Panel — Perfect bottom-right

    private func buildRecordingsPanel() {
        guard let contentView = window?.contentView else { return }

        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.94).cgColor
        panel.layer?.cornerRadius = 6

        // Toggle button — clean, borderless, aligned
        recordingsToggle = NSButton(title: "▸ Recordings", target: self, action: #selector(toggleRecordings))
        guard let toggle = recordingsToggle else { return }
        toggle.isBordered = false
        toggle.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        toggle.attributedTitle = NSAttributedString(
            string: "▸ Recordings",
            attributes: [.foregroundColor: NSColor(calibratedWhite: 0.7, alpha: 1.0),
                         .font: NSFont.systemFont(ofSize: 10, weight: .medium)]
        )
        toggle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(toggle)

        // Scroll view for recording list
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 4

        let grid = NSStackView(frame: .zero)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.orientation = .vertical
        grid.spacing = 4
        grid.alignment = .leading
        grid.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        scrollView.documentView = grid

        panel.addSubview(scrollView)
        contentView.addSubview(panel)

        // Pin panel to exact bottom-right corner
        NSLayoutConstraint.activate([
            panel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            panel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            panel.widthAnchor.constraint(equalToConstant: 240),

            // Toggle aligned at top-left of panel
            toggle.topAnchor.constraint(equalTo: panel.topAnchor, constant: 3),
            toggle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 6),
            toggle.heightAnchor.constraint(equalToConstant: 20),

            // Scroll view fills remaining panel space
            scrollView.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -4),
        ])

        // Start collapsed
        let hc = panel.heightAnchor.constraint(equalToConstant: recordingsCollapsedHeight)
        hc.isActive = true
        recordingsHeightConstraint = hc

        recordingsPanel = panel
        recordingsScrollView = scrollView
        recordingsGrid = grid
        refreshRecordings()
    }

    @objc private func toggleRecordings() {
        if recordingsExpanded { collapseRecordings() } else { expandRecordings() }
    }

    private func expandRecordings() {
        recordingsExpanded = true
        guard let hc = recordingsHeightConstraint, let panel = recordingsPanel else { return }
        hc.constant = recordingsExpandedHeight
        updateRecordingsToggleTitle()
        installDrawerEventMonitor()
        window?.makeFirstResponder(recordingsToggle)
        selectedRecordingIndex = cachedRecordings.isEmpty ? nil : 0
        updateRowSelection()
        // Fetch latest recordings from the guest when the drawer opens.
        fetchRecordingsFromGuest()
        panel.superview?.layoutSubtreeIfNeeded()
    }

    private func collapseRecordings() {
        recordingsExpanded = false
        removeDrawerEventMonitor()
        guard let hc = recordingsHeightConstraint, let panel = recordingsPanel else { return }
        hc.constant = recordingsCollapsedHeight
        updateRecordingsToggleTitle()
        panel.superview?.layoutSubtreeIfNeeded()
        // Give keyboard input back to the guest without forwarding the drawer-closing click.
        window?.makeFirstResponder(virtualMachineView)
    }

    private func updateRecordingsToggleTitle() {
        let arrow = recordingsExpanded ? "▾" : "▸"
        recordingsToggle?.attributedTitle = NSAttributedString(
            string: "\(arrow) Recordings · \(drawerState.title)",
            attributes: [.foregroundColor: NSColor(calibratedWhite: 0.7, alpha: 1.0),
                         .font: NSFont.systemFont(ofSize: 10, weight: .medium)]
        )
    }

    private func installDrawerEventMonitor() {
        guard drawerEventMonitor == nil else { return }
        drawerEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, self.recordingsExpanded, event.window === self.window else { return event }
            return self.handleDrawerEvent(event)
        }
    }

    private func removeDrawerEventMonitor() {
        if let drawerEventMonitor {
            NSEvent.removeMonitor(drawerEventMonitor)
            self.drawerEventMonitor = nil
        }
    }

    private func handleDrawerEvent(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown {
            switch event.keyCode {
            case 126: // Up
                moveDrawerSelection(by: -1)
                return nil
            case 125: // Down
                moveDrawerSelection(by: 1)
                return nil
            case 36, 76: // Return / keypad Enter
                activateDrawerSelection()
                return nil
            case 53: // Escape
                collapseRecordings()
                return nil
            default:
                // While open, the drawer owns keyboard mode; do not leak typing to the guest.
                return nil
            }
        }

        // The VZ view fills the content area behind the drawer. Consume the first click
        // outside the drawer so it restores guest input without activating a guest control.
        let location = event.locationInWindow
        if let panel = recordingsPanel,
           panel.bounds.contains(panel.convert(location, from: nil)) {
            return event
        }
        if virtualMachineView.bounds.contains(virtualMachineView.convert(location, from: nil)) {
            collapseRecordings()
            return nil
        }
        return event
    }

    private func moveDrawerSelection(by delta: Int) {
        guard !cachedRecordings.isEmpty else { return }
        let current = selectedRecordingIndex ?? (delta > 0 ? -1 : 0)
        selectedRecordingIndex = min(max(current + delta, 0), cachedRecordings.count - 1)
        updateRowSelection()
    }

    private func activateDrawerSelection() {
        guard !commandPending,
              let index = selectedRecordingIndex,
              cachedRecordings.indices.contains(index) else { return }
        playRecordingInGuest(named: cachedRecordings[index].name)
    }

    private func updateRowSelection() {
        for (index, row) in recordingRows.enumerated() {
            let selected = recordingsExpanded && index == selectedRecordingIndex
            row.layer?.backgroundColor = selected
                ? NSColor(calibratedWhite: 0.24, alpha: 1.0).cgColor
                : NSColor(calibratedWhite: 0.14, alpha: 1.0).cgColor
        }
    }

    // MARK: - Recordings list (metadata from guest only)

    private func refreshRecordings() {
        updateRecordingsToggleTitle()
        guard let grid = recordingsGrid else { return }
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        recordingRows.removeAll()
        playButtons.removeAll()

        let status = NSTextField(labelWithString: drawerState.title)
        status.font = NSFont.systemFont(ofSize: 9, weight: .semibold)
        status.textColor = drawerState.color
        status.lineBreakMode = .byTruncatingTail
        status.toolTip = drawerState.detail
        grid.addArrangedSubview(status)

        if let detail = drawerState.detail, !detail.isEmpty {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = NSFont.systemFont(ofSize: 8)
            detailLabel.textColor = NSColor.secondaryLabelColor
            detailLabel.lineBreakMode = .byTruncatingTail
            detailLabel.toolTip = detail
            grid.addArrangedSubview(detailLabel)
        }

        for rec in cachedRecordings {
            let row = makeRecordingRow(name: rec.name, date: rec.date)
            recordingRows.append(row)
            grid.addArrangedSubview(row)
        }
        if let selectedRecordingIndex,
           !cachedRecordings.indices.contains(selectedRecordingIndex) {
            self.selectedRecordingIndex = cachedRecordings.isEmpty ? nil : 0
        }
        updateRowSelection()
        updateControlAvailability()
    }

    private func setDrawerState(_ state: DrawerState) {
        drawerState = state
        refreshRecordings()
    }

    private func failureState(for message: String) -> DrawerState {
        let normalized = message.lowercased()
        let namesOpenAdapt = normalized.contains("openadapt") || normalized.contains("open adapt")
        let indicatesMissing = normalized.contains("missing")
            || normalized.contains("not found")
            || normalized.contains("not installed")
            || normalized.contains("no such file")
            || normalized.contains("doesn't exist")
            || normalized.contains("doesn’t exist")
            || normalized.contains("couldn't be opened")
            || normalized.contains("couldn’t be opened")
            || normalized.contains("enoent")
            || normalized.contains("unavailable")
        if namesOpenAdapt && indicatesMissing {
            return .openAdaptMissing(message)
        }
        return .commandFailed(message)
    }

    private func setCommandPending(_ pending: Bool) {
        commandPending = pending
        updateControlAvailability()
    }

    private func updateControlAvailability() {
        recordButton.isEnabled = !commandPending && controller.guestSocketClient != nil
        for button in playButtons {
            button.isEnabled = !commandPending
        }
    }

    /// Asynchronously fetch the recording list from the guest helper.
    /// On failure, shows an honest error state in the drawer.
    func fetchRecordingsFromGuest() {
        guard !commandPending else { return }
        guard let client = controller.guestSocketClient else {
            setDrawerState(.guestUnavailable("Guest helper is not connected"))
            FileHandle.standardError.write(Data("BuzzBot: no guest socket client — guest helper unreachable\n".utf8))
            return
        }
        setDrawerState(.connecting)
        setCommandPending(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setCommandPending(false) }
            do {
                let response = try await client.send(.init(action: .recordingsList))
                if response.ok {
                    self.cachedRecordings = response.recordings ?? []
                    self.selectedRecordingIndex = self.cachedRecordings.isEmpty ? nil : 0
                    if self.isRecording {
                        self.setDrawerState(.recording)
                    } else {
                        self.setDrawerState(self.cachedRecordings.isEmpty ? .noRecordings : .ready)
                    }
                } else {
                    FileHandle.standardError.write(Data("BuzzBot: guest recordings.list failed: \(response.message)\n".utf8))
                    // Preserve the last confirmed list: a failed connection is not an empty list.
                    self.setDrawerState(self.failureState(for: response.message))
                }
            } catch {
                FileHandle.standardError.write(Data("BuzzBot: guest socket error: \(error.localizedDescription)\n".utf8))
                // Preserve cached metadata and expose connection failure honestly.
                self.setDrawerState(.guestUnavailable(error.localizedDescription))
            }
        }
    }

    private func makeRecordingRow(name: String, date: String) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 3
        row.layer?.backgroundColor = NSColor(calibratedWhite: 0.14, alpha: 1.0).cgColor
        row.translatesAutoresizingMaskIntoConstraints = false

        // Play button ▶ — plays inside the guest, not on the host
        let playBtn = NSButton(title: "▶", target: self, action: #selector(playRecording))
        playBtn.isBordered = false
        playBtn.font = NSFont.systemFont(ofSize: 10)
        playBtn.contentTintColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.toolTip = "Play in guest VM"

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        nameLabel.textColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingTail

        let dateLabel = NSTextField(labelWithString: date)
        dateLabel.font = NSFont.systemFont(ofSize: 8)
        dateLabel.textColor = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(playBtn)
        row.addSubview(nameLabel)
        row.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 36),

            playBtn.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            playBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            playBtn.widthAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 4),
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),

            dateLabel.leadingAnchor.constraint(equalTo: playBtn.trailingAnchor, constant: 4),
            dateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            dateLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),
        ])

        // Store the recording name on the play button for retrieval.
        // Playback is always requested through the guest protocol; no host file is opened.
        playBtn.identifier = NSUserInterfaceItemIdentifier(name)
        playButtons.append(playBtn)
        return row
    }

    @objc private func playRecording(_ sender: NSButton) {
        guard let recordingName = sender.identifier?.rawValue else { return }
        playRecordingInGuest(named: recordingName)
    }

    private func playRecordingInGuest(named recordingName: String) {
        guard !commandPending else { return }
        guard let client = controller.guestSocketClient else {
            setDrawerState(.guestUnavailable("Guest helper is not connected"))
            FileHandle.standardError.write(Data("BuzzBot: cannot play — guest helper unreachable\n".utf8))
            return
        }
        setDrawerState(.connecting)
        setCommandPending(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setCommandPending(false) }
            do {
                let response = try await client.send(.init(action: .recordingPlay, name: recordingName))
                if response.ok {
                    self.setDrawerState(self.isRecording ? .recording : .ready)
                    FileHandle.standardError.write(Data("BuzzBot: guest playing \(recordingName)\n".utf8))
                } else {
                    self.setDrawerState(self.failureState(for: response.message))
                    FileHandle.standardError.write(Data("BuzzBot: guest play failed: \(response.message)\n".utf8))
                }
            } catch {
                self.setDrawerState(.guestUnavailable(error.localizedDescription))
                FileHandle.standardError.write(Data("BuzzBot: play socket error: \(error.localizedDescription)\n".utf8))
            }
        }
    }

    // MARK: - Record Button — clean pill, not ugly grey box

    @objc private func recordButtonClicked() {
        isRecording ? stopRecording() : startRecording()
    }

    @objc private func refreshButtonClicked() {
        guard let machine = attachedMachine else { return }
        virtualMachineView.virtualMachine = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.virtualMachineView.virtualMachine = machine
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }

    private func startRecording() {
        guard !commandPending else { return }
        guard let client = controller.guestSocketClient else {
            setDrawerState(.guestUnavailable("Guest helper is not connected"))
            FileHandle.standardError.write(Data("BuzzBot: cannot record — guest helper unreachable\n".utf8))
            return
        }

        // Generate a recording name for the guest.
        let recID = "recording-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))"
        setDrawerState(.connecting)
        setCommandPending(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setCommandPending(false) }
            do {
                let response = try await client.send(.init(action: .recordStart, name: recID, video: true, audio: false))
                if response.ok {
                    // The red treatment starts only after the guest confirms record.start.
                    self.isRecording = true
                    self.recordButton.layer?.backgroundColor = NSColor.systemRed.cgColor
                    self.recordButton.attributedTitle = NSAttributedString(
                        string: "■",
                        attributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 9, weight: .bold)]
                    )
                    self.startRedGlow()
                    self.setDrawerState(.recording)
                    FileHandle.standardError.write(Data("BuzzBot: guest recording started (\(recID))\n".utf8))
                } else {
                    self.setDrawerState(self.failureState(for: response.message))
                    FileHandle.standardError.write(Data("BuzzBot: guest record.start failed: \(response.message)\n".utf8))
                }
            } catch {
                self.setDrawerState(.guestUnavailable(error.localizedDescription))
                FileHandle.standardError.write(Data("BuzzBot: record socket error: \(error.localizedDescription)\n".utf8))
            }
        }
    }

    private func stopRecording() {
        guard !commandPending else { return }
        guard let client = controller.guestSocketClient else {
            setDrawerState(.guestUnavailable("Guest helper is not connected"))
            FileHandle.standardError.write(Data("BuzzBot: cannot stop — guest helper unreachable\n".utf8))
            return
        }

        setDrawerState(.connecting)
        setCommandPending(true)
        Task { @MainActor [weak self] in
            guard let self else { return }
            var refreshAfterStop = false
            defer {
                self.setCommandPending(false)
                if refreshAfterStop {
                    self.fetchRecordingsFromGuest()
                }
            }
            do {
                let response = try await client.send(.init(action: .recordStop))
                if response.ok {
                    self.isRecording = false
                    self.stopRedGlow()
                    self.recordButton.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.7).cgColor
                    self.recordButton.attributedTitle = NSAttributedString(
                        string: "●",
                        attributes: [.foregroundColor: NSColor(calibratedWhite: 0.85, alpha: 1.0),
                                     .font: NSFont.systemFont(ofSize: 9, weight: .medium)]
                    )
                    self.setDrawerState(.ready)
                    refreshAfterStop = true
                    FileHandle.standardError.write(Data("BuzzBot: guest recording stopped\n".utf8))
                } else {
                    // Keep the confirmed recording glow: the guest did not confirm it stopped.
                    self.setDrawerState(self.failureState(for: response.message))
                    FileHandle.standardError.write(Data("BuzzBot: guest record.stop failed: \(response.message)\n".utf8))
                }
            } catch {
                // Connection loss does not prove the recording stopped.
                self.setDrawerState(.guestUnavailable(error.localizedDescription))
                FileHandle.standardError.write(Data("BuzzBot: stop socket error: \(error.localizedDescription)\n".utf8))
            }
        }
    }

    // MARK: - Red glow visual feedback

    private func startRedGlow() {
        // Red glow behind VM
        virtualMachineView.layer?.shadowColor = NSColor.systemRed.cgColor
        virtualMachineView.layer?.shadowOpacity = 0.7
        virtualMachineView.layer?.shadowRadius = 16
        virtualMachineView.layer?.shadowOffset = .zero

        redGlowTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                let anim = CABasicAnimation(keyPath: "shadowOpacity")
                anim.fromValue = 0.3
                anim.toValue = 0.7
                anim.duration = 1.0
                anim.autoreverses = true
                anim.repeatCount = .infinity
                self.virtualMachineView.layer?.add(anim, forKey: "redGlow")
            }
        }
    }

    private func stopRedGlow() {
        virtualMachineView.layer?.shadowOpacity = 0
        virtualMachineView.layer?.removeAnimation(forKey: "redGlow")
        redGlowTimer?.invalidate()
        redGlowTimer = nil
    }
}