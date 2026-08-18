import AppKit
import Foundation
@preconcurrency import Virtualization

@MainActor
final class OPNDRMVMMainWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private var tableView: NSTableView!
    private var vmListView: NSView!
    private var contentView: NSView!
    private var vmDisplayView: NSView!
    private var welcomeLabel: NSTextField!
    private var vmInstances: [String: VMInstance] = [:]
    private(set) var selectedVM: String?
    private var layoutControl: NSSegmentedControl!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OPNDRM VM"
        window.minSize = NSSize(width: 700, height: 450)
        super.init(window: window)
        window.delegate = self
        setupUI()
        refreshVMList()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - VM Instance

    private class VMInstance {
        let name: String
        let controller: VirtualMachineController
        let windowController: OPNDRMVMWindowController
        var vmView: VZVirtualMachineView?

        init(name: String, controller: VirtualMachineController, windowController: OPNDRMVMWindowController) {
            self.name = name
            self.controller = controller
            self.windowController = windowController
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let window = window else { return }
        let splitView = NSSplitView(frame: window.contentView!.bounds)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]

        // Sidebar
        vmListView = NSView()
        vmListView.wantsLayer = true
        vmListView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: "Virtual Machines")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(titleLabel)

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 52
        tableView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("vm"))
        tableView.addTableColumn(column)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(scrollView)

        let newButton = NSButton(title: "+ New VM", target: self, action: #selector(newVMClicked))
        newButton.bezelStyle = .rounded
        newButton.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(newButton)

        layoutControl = NSSegmentedControl(labels: ["Single", "Split", "Triple", "Quad"],
                                            trackingMode: .selectOne, target: self,
                                            action: #selector(layoutChanged))
        layoutControl.selectedSegment = 0
        layoutControl.translatesAutoresizingMaskIntoConstraints = false
        vmListView.addSubview(layoutControl)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: vmListView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: vmListView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: layoutControl.topAnchor, constant: -8),

            layoutControl.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            layoutControl.bottomAnchor.constraint(equalTo: newButton.topAnchor, constant: -8),

            newButton.leadingAnchor.constraint(equalTo: vmListView.leadingAnchor, constant: 12),
            newButton.bottomAnchor.constraint(equalTo: vmListView.bottomAnchor, constant: -12),
        ])

        // Content area
        contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

        welcomeLabel = NSTextField(labelWithString: "Select a VM or create a new one")
        welcomeLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        welcomeLabel.textColor = .secondaryLabelColor
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(welcomeLabel)
        NSLayoutConstraint.activate([
            welcomeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            welcomeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        splitView.addSubview(vmListView)
        splitView.addSubview(contentView)
        splitView.setPosition(250, ofDividerAt: 0)

        window.contentView = splitView
    }

    // MARK: - VM List

    func refreshVMList() {
        tableView.reloadData()
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
        let hasState = AgentComputerStore.hasVMState(name)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 52))

        // Status dot
        let dot = NSView(frame: NSRect(x: 8, y: 20, width: 10, height: 10))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = isRunning ? NSColor.systemGreen.cgColor : (hasState ? NSColor.tertiaryLabelColor.cgColor : NSColor.systemOrange.cgColor)
        dot.layer?.cornerRadius = 5
        container.addSubview(dot)

        // VM name
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        // Status text
        let statusText = isRunning ? "Running" : (hasState ? "Stopped" : "No State")
        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = isRunning ? .systemGreen : .tertiaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusLabel)

        // Action buttons on the right side
        let playButton = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")!, target: self, action: #selector(playVM(_:)))
        playButton.bezelStyle = .inline
        playButton.tag = row
        playButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(playButton)

        let stopButton = NSButton(image: NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")!, target: self, action: #selector(stopVM(_:)))
        stopButton.bezelStyle = .inline
        stopButton.tag = row
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stopButton)

        let refreshButton = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")!, target: self, action: #selector(refreshVM(_:)))
        refreshButton.bezelStyle = .inline
        refreshButton.tag = row
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(refreshButton)

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

            refreshButton.trailingAnchor.constraint(equalTo: destroyButton.leadingAnchor, constant: -4),
            refreshButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            stopButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -4),
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
        showVM(vmNames[row])
    }

    // MARK: - Actions

    @objc private func playVM(_ sender: NSButton) {
        let row = sender.tag
        guard row < vmNames.count else { return }
        let name = vmNames[row]
        showVM(name)
    }

    @objc private func stopVM(_ sender: NSButton) {
        let row = sender.tag
        guard row < vmNames.count else { return }
        let name = vmNames[row]
        vmInstances[name]?.controller.stop()
        refreshVMList()
    }

    @objc private func refreshVM(_ sender: NSButton) {
        refreshVMList()
    }

    @objc private func destroyVM(_ sender: NSButton) {
        let row = sender.tag
        guard row < vmNames.count else { return }
        let name = vmNames[row]

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Destroy \(name)?"
        alert.informativeText = "This will permanently delete the VM and all its files. This cannot be undone."
        alert.addButton(withTitle: "Destroy")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            vmInstances[name]?.controller.stop()
            try? OPNDRMVMSnapshotManager.destroyVM(name: name)
            vmInstances.removeValue(forKey: name)
            if selectedVM == name {
                selectedVM = nil
                welcomeLabel.isHidden = false
            }
            refreshVMList()
        }
    }

    @objc private func newVMClicked() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Create New VM"
        alert.informativeText = "Choose a VM type, name, and memory allocation."

        let typePopup = NSPopUpButton(frame: NSRect(x: 0, y: 40, width: 200, height: 26), pullsDown: false)
        typePopup.addItems(withTitles: ["Apple (macOS)", "Linux"])
        let nameField = NSTextField(frame: NSRect(x: 0, y: 10, width: 200, height: 24))
        nameField.placeholderString = "VM name"
        let memField = NSTextField(frame: NSRect(x: 210, y: 10, width: 60, height: 24))
        memField.stringValue = "16"
        let memLabel = NSTextField(labelWithString: "GB")

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 70))
        accessory.addSubview(typePopup)
        accessory.addSubview(nameField)
        accessory.addSubview(memField)
        accessory.addSubview(memLabel)
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let memGB = Int(memField.stringValue) ?? 16
            createVM(name: name, memoryGB: memGB)
        }
    }

    func createVM(name: String, memoryGB: Int) {
        // Create VM directory structure
        let dir = AgentComputerStore.agentDir(name)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        refreshVMList()

        // Try to boot it if state files exist
        showVM(name)
    }

    @objc private func layoutChanged(_ control: NSSegmentedControl) {
        // Phase 3: multi-VM layout
    }

    // MARK: - VM Display

    func showVM(_ machineID: String) {
        welcomeLabel.isHidden = true

        // If already running, just focus
        if let instance = vmInstances[machineID] {
            instance.windowController.window?.makeKeyAndOrderFront(nil)
            refreshVMList()
            return
        }

        let stateDir = AgentComputerStore.agentDir(machineID)
        guard FileManager.default.fileExists(atPath: stateDir.path) else { return }

        // Check if this is a real VM with state files
        guard AgentComputerStore.hasVMState(machineID) else {
            welcomeLabel.stringValue = "No VM image for \(machineID). Create a VM from IPSW or clone an existing one."
            welcomeLabel.isHidden = false
            return
        }

        // Boot the VM in a floating window
        let controller = VirtualMachineController()
        let overlay = OPNDRMVMWindowController(controller: controller, machineName: machineID)
        vmInstances[machineID] = VMInstance(name: machineID, controller: controller, windowController: overlay)

        bootVM(machineID: machineID, controller: controller, overlay: overlay)
    }

    private func bootVM(machineID: String, controller: VirtualMachineController, overlay: OPNDRMVMWindowController) {
        let appSupport = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).standardizedFileURL
        let stateDir = AgentComputerStore.agentDir(machineID)

        let diskURL = stateDir.appendingPathComponent("Disk.img")
        let auxURL = stateDir.appendingPathComponent("AuxiliaryStorage")
        let machineIDURL = stateDir.appendingPathComponent("MachineIdentifier")
        let lifecycleURL = stateDir.appendingPathComponent("Lifecycle.plist")

        guard let machineIdentifierData = try? Data(contentsOf: machineIDURL),
              let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else { return }

        guard let lifecycleData = try? Data(contentsOf: lifecycleURL),
              let plist = try? PropertyListSerialization.propertyList(from: lifecycleData, options: [], format: nil) as? [String: Any],
              let hardwareModelData = plist["hardwareModelData"] as? Data,
              let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData),
              hardwareModel.isSupported else { return }

        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardwareModel
        platform.machineIdentifier = machineIdentifier
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url: auxURL)

        let diskAttachment = try! VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)

        let config = VZVirtualMachineConfiguration()
        config.cpuCount = 4
        config.memorySize = 8 * 1024 * 1024 * 1024
        config.platform = platform
        config.bootLoader = VZMacOSBootLoader()
        config.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]

        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 80)]
        config.graphicsDevices = [graphics]
        config.keyboards = [VZMacKeyboardConfiguration()]
        config.pointingDevices = [VZMacTrackpadConfiguration()]

        let networkConfig = VZVirtioNetworkDeviceConfiguration()
        networkConfig.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [networkConfig]
        config.socketDevices = [VZVirtioSocketDeviceConfiguration()]

        try! config.validate()

        let vm = VZVirtualMachine(configuration: config)
        controller.setMachine(vm)
        vm.delegate = controller
        controller.start()

        overlay.window?.makeKeyAndOrderFront(nil)
        refreshVMList()
    }
}
