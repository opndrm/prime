import AppKit
import Foundation
@preconcurrency import Virtualization

@MainActor
final class OPNDRMVMMainWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private var tableView: NSTableView!
    private var vmListView: NSView!
    private var contentView: NSView!
    private var welcomeLabel: NSTextField!
    private var vmInstances: [String: VMInstance] = [:]
    private(set) var selectedVM: String?
    private var progressLabel: NSTextField!
    private var progressBar: NSProgressIndicator!
    private var progressCancelButton: NSButton!
    private var layoutView: OPNDRMVMLayoutView!
    private var agentCanvasConsole: OPNDRMAgentCanvasConsoleView!
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var sidebarToggleButton: NSButton!
    private var agentButton: NSButton!
    private var sidebarCollapsibleViews: [NSView] = []
    private var isSidebarCollapsed = false
    private let expandedSidebarWidth: CGFloat = 280
    private let collapsedSidebarWidth: CGFloat = 56
    private var isCreationCancelled = false
    private var agentHolders: [String: OPNDRMAgentHarnessHolder] = [:]

    private class VMInstance {
        let name: String
        let controller: VirtualMachineController
        var vmView: VZVirtualMachineView?
        var windowController: OPNDRMVMWindowController?
        var isInstalling = false

        init(name: String, controller: VirtualMachineController) {
            self.name = name
            self.controller = controller
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OPNDRM"
        window.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 1)
        window.minSize = NSSize(width: 900, height: 560)
        // Keep the green button as a sane zoom action, not native fullscreen/tiling.
        // The VM surface has its own visualizer/layout and should stay inside
        // the visible desktop frame instead of overlapping the menu bar/dock.
        window.collectionBehavior = [.fullScreenNone]
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self
        setupUI()
        fitWindowToVisibleScreen()
        refreshVMList()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - UI Setup

    private func setupUI() {
        guard let window = window else { return }

        // Use an explicit Auto Layout root instead of NSSplitView. The previous
        // split view allowed the black VM canvas to overlap the sidebar on some
        // launches, making the manager look clipped/glitched. Fixed 280pt rail.
        let rootView = NSView(frame: window.contentView?.bounds ?? window.frame)
        rootView.autoresizingMask = [.width, .height]
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.black.cgColor

        // Sidebar
        vmListView = NSView()
        vmListView.translatesAutoresizingMaskIntoConstraints = false
        vmListView.wantsLayer = true
        vmListView.layer?.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1).cgColor
        vmListView.layer?.masksToBounds = true
        rootView.addSubview(vmListView)

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(titleLabel)

        sidebarToggleButton = NSButton(title: "‹", target: self, action: #selector(toggleSidebarClicked))
        sidebarToggleButton.bezelStyle = .texturedRounded
        sidebarToggleButton.controlSize = .small
        sidebarToggleButton.toolTip = "Collapse sidebar"
        sidebarToggleButton.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(sidebarToggleButton)

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 56
        tableView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("vm"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(scrollView)

        let newButton = NSButton(title: "+ New Computer", target: self, action: #selector(newVMClicked))
        newButton.bezelStyle = .rounded
        newButton.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(newButton)

        agentButton = NSButton(title: "💬 Agent", target: self, action: #selector(showAgentClicked))
        agentButton.bezelStyle = .rounded
        agentButton.controlSize = .large
        agentButton.toolTip = "Open the named agent for the selected VM"
        agentButton.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(agentButton)

        // Progress indicator
        progressBar = NSProgressIndicator(frame: .zero)
        progressBar.style = .bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true
        vmListView.addSubview(progressBar)

        progressLabel = NSTextField(labelWithString: "")
        progressLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        progressLabel.textColor = NSColor(calibratedWhite: 0.45, alpha: 1)
        progressLabel.lineBreakMode = .byWordWrapping
        progressLabel.maximumNumberOfLines = 3
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.isHidden = true
        vmListView.addSubview(progressLabel)

        progressCancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelCreationClicked))
        progressCancelButton.bezelStyle = .rounded
        progressCancelButton.translatesAutoresizingMaskIntoConstraints = false
        progressCancelButton.isHidden = true
        vmListView.addSubview(progressCancelButton)

        sidebarCollapsibleViews = [
            titleLabel,
            scrollView,
            agentButton,
            newButton,
        ]

        // Content area - holds the layout view
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 1).cgColor
        rootView.addSubview(contentView)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(separator)

        sidebarWidthConstraint = vmListView.widthAnchor.constraint(equalToConstant: expandedSidebarWidth)

        NSLayoutConstraint.activate([
            vmListView.topAnchor.constraint(equalTo: rootView.topAnchor),
            vmListView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            vmListView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            sidebarWidthConstraint,

            separator.topAnchor.constraint(equalTo: rootView.topAnchor),
            separator.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: vmListView.trailingAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),

            contentView.topAnchor.constraint(equalTo: rootView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: separator.trailingAnchor),
            contentView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            sidebarToggleButton.topAnchor.constraint(equalTo: vmListView.topAnchor, constant: 8),
            sidebarToggleButton.trailingAnchor.constraint(equalTo: vmListView.trailingAnchor, constant: -8),
            sidebarToggleButton.widthAnchor.constraint(equalToConstant: 28),
            sidebarToggleButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: vmListView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: sidebarToggleButton.leadingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: vmListView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -8),

            progressBar.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: vmListView.trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: progressLabel.topAnchor, constant: -4),

            progressLabel.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            progressLabel.trailingAnchor.constraint(equalTo: vmListView.trailingAnchor, constant: -12),
            progressLabel.bottomAnchor.constraint(equalTo: progressCancelButton.topAnchor, constant: -4),

            progressCancelButton.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            progressCancelButton.bottomAnchor.constraint(equalTo: agentButton.topAnchor, constant: -8),

            agentButton.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            agentButton.trailingAnchor.constraint(lessThanOrEqualTo: vmListView.trailingAnchor, constant: -12),
            agentButton.bottomAnchor.constraint(equalTo: newButton.topAnchor, constant: -8),

            newButton.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            newButton.bottomAnchor.constraint(equalTo: vmListView.bottomAnchor, constant: -12),
        ])

        welcomeLabel = NSTextField(labelWithString: "Starting your agent's computer…")
        welcomeLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        welcomeLabel.textColor = NSColor(calibratedWhite: 0.5, alpha: 1)
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(welcomeLabel)
        NSLayoutConstraint.activate([
            welcomeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            welcomeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        // Layout view for multi-VM display
        layoutView = OPNDRMVMLayoutView(frame: .zero)
        layoutView.translatesAutoresizingMaskIntoConstraints = false
        layoutView.isHidden = true
        contentView.addSubview(layoutView)
        NSLayoutConstraint.activate([
            layoutView.topAnchor.constraint(equalTo: contentView.topAnchor),
            layoutView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            layoutView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            layoutView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        // First Mate chooser/chat overlay. This is the stress-free product
        // surface: users choose Prime Agent or JCode in the VM canvas, then chat.
        agentCanvasConsole = OPNDRMAgentCanvasConsoleView(frame: .zero)
        agentCanvasConsole.isHidden = true
        agentCanvasConsole.onStartRequested = { [weak self] vmName, kind, agentName, emoji, instructions in
            self?.startFirstMate(
                vmName: vmName,
                kind: kind,
                agentName: agentName,
                emoji: emoji,
                instructions: instructions
            )
        }
        agentCanvasConsole.onHideRequested = { [weak self] in
            self?.hideAgentConsole()
        }
        contentView.addSubview(agentCanvasConsole, positioned: .above, relativeTo: layoutView)
        agentCanvasConsole.layer?.zPosition = 9_999
        NSLayoutConstraint.activate([
            agentCanvasConsole.topAnchor.constraint(equalTo: contentView.topAnchor),
            agentCanvasConsole.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            agentCanvasConsole.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            agentCanvasConsole.widthAnchor.constraint(equalToConstant: 380),
        ])

        window.contentView = rootView
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        window.setFrame(standardVisibleFrame(for: window), display: true, animate: true)
        return false
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        standardVisibleFrame(for: window)
    }

    func windowDidResize(_ notification: Notification) {
        // Do not clamp continuously while the user drags a resize handle; it
        // feels sticky. Clamp only after live resize completes.
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        clampWindowToVisibleScreen(animated: true)
    }

    func windowDidMove(_ notification: Notification) {
        clampWindowToVisibleScreen(animated: false)
    }

    private func standardVisibleFrame(for window: NSWindow) -> NSRect {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let margin: CGFloat = 14
        var frame = visible.insetBy(dx: margin, dy: margin)
        frame.size.width = max(window.minSize.width, frame.width)
        frame.size.height = max(window.minSize.height, frame.height)
        if frame.width > visible.width { frame.size.width = visible.width }
        if frame.height > visible.height { frame.size.height = visible.height }
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        return frame
    }

    private func fitWindowToVisibleScreen() {
        guard let window else { return }
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let screenFrame else { return }
        let margin: CGFloat = 14
        let maxWidth = max(window.minSize.width, screenFrame.width - margin * 2)
        let maxHeight = max(window.minSize.height, screenFrame.height - margin * 2)
        var frame = window.frame
        frame.size.width = min(frame.width, maxWidth)
        frame.size.height = min(frame.height, maxHeight)
        frame.origin.x = min(max(frame.origin.x, screenFrame.minX + margin), screenFrame.maxX - frame.width - margin)
        frame.origin.y = min(max(frame.origin.y, screenFrame.minY + margin), screenFrame.maxY - frame.height - margin)
        window.setFrame(frame, display: true)
    }

    private func clampWindowToVisibleScreen(animated: Bool = false) {
        guard let window else { return }
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let screenFrame else { return }
        var frame = window.frame
        var changed = false
        if frame.width > screenFrame.width {
            frame.size.width = screenFrame.width
            frame.origin.x = screenFrame.minX
            changed = true
        }
        if frame.height > screenFrame.height {
            frame.size.height = screenFrame.height
            frame.origin.y = screenFrame.minY
            changed = true
        }
        if frame.minX < screenFrame.minX {
            frame.origin.x = screenFrame.minX
            changed = true
        }
        if frame.maxX > screenFrame.maxX {
            frame.origin.x = screenFrame.maxX - frame.width
            changed = true
        }
        if frame.minY < screenFrame.minY {
            frame.origin.y = screenFrame.minY
            changed = true
        }
        if frame.maxY > screenFrame.maxY {
            frame.origin.y = screenFrame.maxY - frame.height
            changed = true
        }
        if changed {
            window.setFrame(frame, display: true, animate: animated)
        }
    }

    func autoBootDefaultVM() {
        guard vmInstances.values.allSatisfy({ $0.controller.lifecycle != .running && $0.controller.lifecycle != .starting }) else { return }
        let bootable = vmNames.filter { AgentComputerStore.hasVMState($0) }
        let preferred = selectedVM.flatMap { AgentComputerStore.hasVMState($0) ? $0 : nil }
            ?? bootable.first(where: { $0 == "linux-1" })
            ?? bootable.first(where: { AgentComputerStore.vmType($0) == .linux })
            ?? bootable.first
        guard let preferred else {
            welcomeLabel.stringValue = "Create a Linux Quick Start VM to begin."
            return
        }
        selectedVM = preferred
        progressLabel.isHidden = false
        progressLabel.stringValue = "Booting \(preferred)…"
        bootVM(preferred)
    }

    // MARK: - VM List

    func refreshVMList() {
        tableView.reloadData()
    }

    func handleAICommand(_ request: [String: Any]) -> [String: Any] {
        let action = (request["action"] as? String) ?? ""
        switch action {
        case "ping":
            return ["ok": true, "message": "pong"]
        case "status", "list":
            let machines: [[String: Any]] = vmNames.map { name in
                let instance = vmInstances[name]
                return [
                    "name": name,
                    "type": AgentComputerStore.vmType(name).rawValue,
                    "bootable": AgentComputerStore.hasVMState(name),
                    "lifecycle": instance?.controller.lifecycle.rawValue ?? (AgentComputerStore.hasVMState(name) ? "stopped" : "no-image"),
                    "status": instance?.controller.statusText ?? ""
                ]
            }
            return [
                "ok": true,
                "mode": "manager",
                "layout": "single",
                "selectedVM": selectedVM ?? "",
                "vms": machines
            ]
        case "create":
            guard let name = request["name"] as? String, !name.isEmpty else {
                return ["ok": false, "message": "create requires name"]
            }
            let rawType = (request["type"] as? String)?.lowercased() ?? "linux"
            let type: VMType = rawType.contains("mac") || rawType.contains("apple") ? .apple : .linux
            let memoryGB = Self.intValue(request["memoryGB"], defaultValue: type == .apple ? 8 : 4)
            createVM(name: name, type: type, memoryGB: memoryGB)
            return ["ok": true, "message": "creating \(type.rawValue) VM: \(name)"]
        case "boot", "start":
            guard let name = request["name"] as? String, !name.isEmpty else {
                return ["ok": false, "message": "boot requires name"]
            }
            bootVM(name)
            return ["ok": true, "message": "boot requested: \(name)"]
        case "console.write", "type", "sendKeys":
            let name = (request["name"] as? String) ?? selectedVM ?? ""
            guard !name.isEmpty else { return ["ok": false, "message": "console.write requires a selected VM or name"] }
            let text = (request["text"] as? String) ?? (request["keys"] as? String) ?? ""
            guard !text.isEmpty else { return ["ok": false, "message": "console.write requires text"] }
            guard let controller = vmInstances[name]?.controller else { return ["ok": false, "message": "\(name) is not running in this window"] }
            let ok = controller.writeLinuxConsole(text)
            return ["ok": ok, "message": ok ? "sent to \(name) console" : "\(name) has no writable Linux console"]
        case "console.read":
            let name = (request["name"] as? String) ?? selectedVM ?? ""
            guard !name.isEmpty else { return ["ok": false, "message": "console.read requires a selected VM or name"] }
            guard let controller = vmInstances[name]?.controller else { return ["ok": false, "message": "\(name) is not running in this window"] }
            return ["ok": true, "name": name, "console": controller.readLinuxConsole(limit: Self.intValue(request["limit"], defaultValue: 4000))]
        case "showVM", "hideAgent":
            hideAgentConsole()
            return ["ok": true, "message": "showing VM visualizer"]
        case "stop":
            guard let name = request["name"] as? String, !name.isEmpty else {
                return ["ok": false, "message": "stop requires name"]
            }
            if let instance = vmInstances[name] {
                instance.controller.stop()
                instance.vmView?.removeFromSuperview()
                vmInstances.removeValue(forKey: name)
            }
            if selectedVM == name { selectedVM = nil }
            displayVMInLayout()
            refreshVMList()
            return ["ok": true, "message": "stopped \(name); press/play boot to recreate the visualizer"]
        case "layout", "setLayout":
            let rawMode = (request["mode"] as? String)?.lowercased() ?? "single"
            let mode: VMLayoutMode
            switch rawMode {
            case "split", "2": mode = .split
            case "triple", "3": mode = .triple
            case "quad", "4": mode = .quad
            default: mode = .single
            }
            layoutView.layoutMode = mode
            displayVMInLayout()
            return ["ok": true, "message": "layout set to \(mode.description)"]
        default:
            return ["ok": false, "message": "unknown action: \(action)"]
        }
    }

    private var vmNames: [String] {
        AgentComputerStore.listAgents()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        vmNames.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let name = vmNames[row]
        let isRunning = vmInstances[name]?.controller.lifecycle == .running
        let isInstalling = vmInstances[name]?.isInstalling == true
        let hasState = AgentComputerStore.hasVMState(name)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 52))

        // Status dot
        let dot = NSView(frame: NSRect(x: 8, y: 20, width: 10, height: 10))
        dot.wantsLayer = true
        let dotColor: CGColor = isRunning ? NSColor.systemGreen.cgColor : (isInstalling ? NSColor.systemBlue.cgColor : (hasState ? NSColor.tertiaryLabelColor.cgColor : NSColor.systemOrange.cgColor))
        dot.layer?.backgroundColor = dotColor
        dot.layer?.cornerRadius = 5
        container.addSubview(dot)

        // VM name
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        // Status text
        let statusText = isRunning ? "Running" : (isInstalling ? "Installing" : (hasState ? "Stopped" : "No Image"))
        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = isRunning ? .systemGreen : (isInstalling ? .systemBlue : (hasState ? .tertiaryLabelColor : .systemOrange))
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusLabel)

        // Action buttons
        let playButton = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Start")!, target: self, action: #selector(playVM(_:)))
        playButton.bezelStyle = .inline
        playButton.tag = row
        playButton.isEnabled = hasState || isInstalling
        playButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(playButton)

        let stopButton = NSButton(image: NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")!, target: self, action: #selector(stopVM(_:)))
        stopButton.bezelStyle = .inline
        stopButton.tag = row
        stopButton.isEnabled = isRunning
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stopButton)

        let destroyButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Destroy")!, target: self, action: #selector(destroyVM(_:)))
        destroyButton.bezelStyle = .inline
        destroyButton.tag = row
        destroyButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(destroyButton)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 26),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),

            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 26),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            destroyButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            destroyButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            stopButton.trailingAnchor.constraint(equalTo: destroyButton.leadingAnchor, constant: -4),
            stopButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            playButton.trailingAnchor.constraint(equalTo: stopButton.leadingAnchor, constant: -4),
            playButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < vmNames.count else { return }
        selectedVM = vmNames[row]
        displayVMInLayout()
    }

    // MARK: - Actions

    @objc private func playVM(_ sender: NSButton) {
        let row = sender.tag
        guard row < vmNames.count else { return }
        let name = vmNames[row]
        bootVM(name)
    }

    @objc private func stopVM(_ sender: NSButton) {
        let row = sender.tag
        guard row < vmNames.count else { return }
        let name = vmNames[row]
        if let instance = vmInstances[name] {
            instance.controller.stop()
            instance.vmView?.removeFromSuperview()
            vmInstances.removeValue(forKey: name)
        }
        if selectedVM == name { selectedVM = nil }
        displayVMInLayout()
        progressLabel.isHidden = false
        progressLabel.stringValue = "\(name) stopped. Press Play to start it again."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.refreshVMList() }
    }

    @objc private func destroyVM(_ sender: NSButton) {
        let row = sender.tag
        guard row < vmNames.count else { return }
        let name = vmNames[row]

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Destroy \(name)?"
        alert.informativeText = "This permanently deletes the VM and all files. Cannot be undone."
        alert.addButton(withTitle: "Destroy")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            vmInstances[name]?.controller.stop()
            try? OPNDRMVMSnapshotManager.destroyVM(name: name)
            vmInstances.removeValue(forKey: name)
            displayVMInLayout()
            refreshVMList()
        }
    }

    @objc private func toggleSidebarClicked() {
        isSidebarCollapsed.toggle()
        let targetWidth = isSidebarCollapsed ? collapsedSidebarWidth : expandedSidebarWidth
        sidebarToggleButton.title = isSidebarCollapsed ? "›" : "‹"
        sidebarToggleButton.toolTip = isSidebarCollapsed ? "Open sidebar" : "Collapse sidebar"

        if !isSidebarCollapsed {
            for view in sidebarCollapsibleViews {
                view.isHidden = false
                view.alphaValue = 0
            }
        }

        let collapsed = isSidebarCollapsed
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.sidebarWidthConstraint.animator().constant = targetWidth
            for view in self.sidebarCollapsibleViews {
                view.animator().alphaValue = collapsed ? 0 : 1
            }
            self.window?.contentView?.layoutSubtreeIfNeeded()
        } completionHandler: {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for view in self.sidebarCollapsibleViews {
                    view.isHidden = collapsed
                    view.alphaValue = collapsed ? 0 : 1
                }
            }
        }
    }

    @objc private func showAgentClicked() {
        if agentCanvasConsole.isHidden == false {
            hideAgentConsole()
            return
        }
        let candidate = selectedVM
            ?? vmNames.first(where: { AgentComputerStore.vmType($0) == .linux && AgentComputerStore.hasVMState($0) })
            ?? vmNames.first(where: { AgentComputerStore.hasVMState($0) })
        guard let vmName = candidate else {
            showError("Create a Linux Quick Start VM first. Then the agent has a real computer to use.")
            return
        }
        selectedVM = vmName
        if vmInstances[vmName] == nil || vmInstances[vmName]?.controller.lifecycle == .ready || vmInstances[vmName]?.controller.lifecycle == .stopped {
            bootVM(vmName)
        } else {
            displayVMInLayout()
        }
        showFirstMateConsole(for: vmName)
    }



    private func hideAgentConsole() {
        window?.makeFirstResponder(nil)
        agentCanvasConsole.alphaValue = 0
        agentCanvasConsole.isHidden = true
        displayVMInLayout()
    }

    private func showFirstMateConsole(for vmName: String) {
        guard AgentComputerStore.hasVMState(vmName) else { return }
        let existing = agentHolders.values.first { $0.vmName == vmName }
        agentCanvasConsole.layer?.zPosition = 9_999
        agentCanvasConsole.alphaValue = 1
        agentCanvasConsole.isHidden = false
        contentView.addSubview(agentCanvasConsole, positioned: .above, relativeTo: layoutView)
        agentCanvasConsole.configure(vmName: vmName, existingHolder: existing)
    }

    @discardableResult
    private func startFirstMate(
        vmName: String,
        kind: OPNDRMAgentHarnessHolder.Kind,
        agentName: String = "First Mate",
        emoji: String = "🧭",
        instructions: String = "Keep the conversation simple and stress-free. Work only inside your assigned VM. Automate inside the VM when possible. Ask before destructive changes. Do not show Prime Agent or JCode terminal output to the user."
    ) -> OPNDRMAgentHarnessHolder {
        let safeAgentName = agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "First Mate" : agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🧭" : emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "\(vmName):\(kind.safeName):\(safeAgentName)"
        let holder = agentHolders[key] ?? OPNDRMAgentHarnessHolder(
            vmName: vmName,
            kind: kind,
            agentName: safeAgentName,
            emoji: safeEmoji,
            instructions: instructions
        )
        holder.stateDidChange = { [weak self] _, status in
            self?.progressLabel.isHidden = false
            self?.progressLabel.stringValue = status
            self?.agentCanvasConsole.setStatus(status)
            self?.agentCanvasConsole.refreshTranscript()
        }
        agentHolders[key] = holder

        if let instance = vmInstances[vmName] {
            if instance.controller.lifecycle == .ready || instance.controller.lifecycle == .stopped || instance.controller.lifecycle == .paused {
                bootVM(vmName)
            }
        } else if AgentComputerStore.hasVMState(vmName) {
            bootVM(vmName)
        }

        do {
            try holder.start()
        } catch {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(holder.bindingPrompt(), forType: .string)
            selectedVM = vmName
            displayVMInLayout()
            showFirstMateConsole(for: vmName)
            agentCanvasConsole.setStatus("Hidden \(kind.displayName) could not start yet. The VM-bound prompt was copied; no terminal output will be shown.")
        }
        return holder
    }

    @objc private func newVMClicked() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Create New VM"
        alert.informativeText = "Fast path: Linux Quick Start downloads small boot files and boots in minutes.\nMac path: macOS needs a one-time 12–15GB IPSW download, then future VMs can use clones/templates."

        let typePopup = NSPopUpButton(frame: NSRect(x: 0, y: 72, width: 270, height: 26), pullsDown: false)
        typePopup.addItems(withTitles: ["Linux Quick Start", "Apple macOS (large IPSW)"])
        typePopup.selectItem(at: 0)

        let nameLabel = NSTextField(labelWithString: "Name")
        nameLabel.frame = NSRect(x: 0, y: 44, width: 60, height: 18)
        let nameField = NSTextField(frame: NSRect(x: 70, y: 40, width: 200, height: 24))
        nameField.stringValue = "linux-1"

        let memLabel = NSTextField(labelWithString: "Memory")
        memLabel.frame = NSRect(x: 0, y: 14, width: 60, height: 18)
        let memField = NSTextField(frame: NSRect(x: 70, y: 10, width: 60, height: 24))
        memField.stringValue = "4"
        let gbLabel = NSTextField(labelWithString: "GB")
        gbLabel.frame = NSRect(x: 136, y: 14, width: 30, height: 18)

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 104))
        accessory.addSubview(typePopup)
        accessory.addSubview(nameLabel)
        accessory.addSubview(nameField)
        accessory.addSubview(memLabel)
        accessory.addSubview(memField)
        accessory.addSubview(gbLabel)
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let memGB = Int(memField.stringValue) ?? 4
            let isApple = typePopup.indexOfSelectedItem == 1
            createVM(name: name, type: isApple ? .apple : .linux, memoryGB: memGB)
        }
    }

    @objc private func cancelCreationClicked() {
        isCreationCancelled = true
        OPNDRMVMCreator.shared.cancelActiveOperation()
        progressBar.stopAnimation(nil)
        progressBar.isIndeterminate = false
        progressBar.doubleValue = 0
        progressCancelButton.isEnabled = false
        progressLabel.stringValue = "Cancelled. You can create a Linux Quick Start VM or restart macOS setup later."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.isCreationCancelled else { return }
            self.progressBar.isHidden = true
            self.progressLabel.isHidden = true
            self.progressCancelButton.isHidden = true
            self.isCreationCancelled = false
        }
    }

    func createVM(name: String, type: VMType, memoryGB: Int) {
        isCreationCancelled = false
        progressBar.isHidden = false
        progressLabel.isHidden = false
        progressCancelButton.isHidden = false
        progressCancelButton.isEnabled = true
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.isIndeterminate = true
        progressBar.startAnimation(nil)
        progressLabel.stringValue = type == .apple
            ? "Preparing macOS setup for \(name)…"
            : "Preparing Linux Quick Start for \(name)…"

        let progressHandler: (OPNDRMVMCreateProgress) -> Void = { [weak self] progress in
            DispatchQueue.main.async {
                self?.updateCreateProgress(progress)
            }
        }

        switch type {
        case .apple:
            OPNDRMVMCreator.shared.createAppleVM(
                name: name,
                memoryGB: memoryGB,
                onProgress: progressHandler,
                onPrepared: { [weak self] prepared in
                    guard let self else { return }
                    let instance = VMInstance(name: name, controller: prepared.controller)
                    instance.vmView = prepared.view
                    instance.isInstalling = true
                    prepared.controller.stateDidChange = { [weak self] _, _ in
                        self?.refreshVMList()
                        self?.displayVMInLayout()
                    }
                    self.vmInstances[name] = instance
                    self.selectedVM = name
                    self.refreshVMList()
                    self.displayVMInLayout()
                },
                completion: { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.finishCreateProgress()
                        self.vmInstances[name]?.isInstalling = false
                        self.refreshVMList()

                        if self.isCreationCancelled { return }
                        switch result {
                        case .success:
                            self.bootVM(name)
                        case .failure(let error):
                            self.showError("Failed to create \(name): \(error.localizedDescription)")
                        }
                    }
                }
            )
        case .linux:
            OPNDRMVMCreator.shared.createLinuxVM(
                name: name,
                memoryGB: memoryGB,
                onProgress: progressHandler
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.finishCreateProgress()
                    if self.isCreationCancelled { return }

                    switch result {
                    case .success:
                        self.refreshVMList()
                        self.bootVM(name)
                    case .failure(let error):
                        self.showError("Failed to create \(name): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func updateCreateProgress(_ progress: OPNDRMVMCreateProgress) {
        progressLabel.stringValue = "\(progress.phase): \(progress.detail)"
        progressCancelButton.isHidden = !progress.canCancel
        progressCancelButton.isEnabled = progress.canCancel
        if let fraction = progress.fraction {
            progressBar.stopAnimation(nil)
            progressBar.isIndeterminate = false
            progressBar.doubleValue = max(0, min(1, fraction))
        } else {
            progressBar.isIndeterminate = true
            progressBar.startAnimation(nil)
        }
    }

    private func finishCreateProgress() {
        progressBar.stopAnimation(nil)
        progressBar.isHidden = true
        progressLabel.isHidden = true
        progressCancelButton.isHidden = true
    }



    // MARK: - VM Boot and Display

    func bootVM(_ machineID: String) {
        progressLabel.isHidden = false
        progressLabel.stringValue = "Booting \(machineID)…"
        if let existing = vmInstances[machineID] {
            if existing.isInstalling {
                selectedVM = machineID
                displayVMInLayout()
                return
            }

            switch existing.controller.lifecycle {
            case .ready:
                existing.controller.start()
                selectedVM = machineID
                refreshVMList()
                displayVMInLayout()
                return
            case .running, .starting:
                selectedVM = machineID
                refreshVMList()
                displayVMInLayout()
                progressLabel.stringValue = existing.controller.lifecycle == .running ? "\(machineID) is running." : "\(machineID) is starting…"
                return
            case .paused:
                existing.controller.resume()
                selectedVM = machineID
                refreshVMList()
                displayVMInLayout()
                return
            case .stopped, .failed, .unconfigured, .stopping, .pausing:
                // A stopped VZVirtualMachine cannot be restarted after its
                // machine has been torn down. Throw away the dead view and load
                // a fresh visualizer/controller from disk below.
                existing.controller.stop()
                existing.vmView?.removeFromSuperview()
                vmInstances.removeValue(forKey: machineID)
            }
        }

        guard AgentComputerStore.hasVMState(machineID) else {
            showError("No bootable VM image for \(machineID). Create a macOS VM from IPSW or a Linux VM from the New VM dialog.")
            return
        }

        do {
            let prepared = try OPNDRMVMCreator.shared.loadExistingVM(name: machineID)
            let instance = VMInstance(name: machineID, controller: prepared.controller)
            instance.vmView = prepared.view
            prepared.controller.stateDidChange = { [weak self] lifecycle, status in
                self?.refreshVMList()
                self?.displayVMInLayout()
                self?.progressLabel.isHidden = false
                self?.progressLabel.stringValue = lifecycle == .running ? "\(machineID) is running." : "\(machineID): \(status)"
            }
            prepared.controller.machineDidStart = { [weak self] _ in
                self?.refreshVMList()
                self?.displayVMInLayout()
            }
            vmInstances[machineID] = instance
            selectedVM = machineID
            prepared.controller.start()
            refreshVMList()
            displayVMInLayout()
        } catch {
            showError("Cannot boot \(machineID): \(error.localizedDescription)")
        }
    }

    // MARK: - Layout Display

    func displayVMInLayout() {
        let visibleVMs = vmInstances.filter { _, instance in
            instance.isInstalling
                || instance.controller.lifecycle == .running
                || instance.controller.lifecycle == .ready
                || instance.controller.lifecycle == .starting
                || instance.controller.lifecycle == .paused
        }
        let selected = selectedVM ?? visibleVMs.keys.first

        if visibleVMs.isEmpty || selected == nil {
            welcomeLabel.isHidden = false
            layoutView.isHidden = true
            agentCanvasConsole?.isHidden = true
            return
        }

        welcomeLabel.isHidden = true
        layoutView.isHidden = false

        // Collect VM views for the layout
        var views: [VZVirtualMachineView] = []
        let layoutMode: VMLayoutMode = .single

        // Add selected VM first, then others up to tileCount
        if let selectedVM = selected, let instance = vmInstances[selectedVM], let view = instance.vmView {
            views.append(view)
        }
        for (name, instance) in visibleVMs {
            if name == selected { continue }
            if let view = instance.vmView {
                views.append(view)
            }
            if views.count >= layoutMode.tileCount { break }
        }

        layoutView.setVMViews(views)
    }

    // MARK: - Helpers

    private static func intValue(_ value: Any?, defaultValue: Int) -> Int {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let int = Int(string) { return int }
        return defaultValue
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}


private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
