import AppKit
import Foundation
@preconcurrency import Virtualization

@MainActor
final class OPNDRMVMMainWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    private var tableView: NSTableView!
    private var vmListView: NSView!
    private var contentView: NSView!
    private var vmWindows: [String: OPNDRMVMWindowController] = [:]
    private var controllers: [String: VirtualMachineController] = [:]
    private(set) var selectedVM: String?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OPNDRM VM"
        window.minSize = NSSize(width: 600, height: 400)
        super.init(window: window)
        window.delegate = self
        setupUI()
        refreshVMList()
    }

    required init?(coder: NSCoder) { nil }

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
        tableView.rowHeight = 44
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

        let layoutControl = NSSegmentedControl(labels: ["Single", "Split", "Triple", "Quad"],
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

        let welcomeLabel = NSTextField(labelWithString: "Select a VM or create a new one")
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
        splitView.setPosition(220, ofDividerAt: 0)

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
        let cell = NSTextField(labelWithString: name)
        let isRunning = controllers[name]?.lifecycle == .running

        let container = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 44))
        let dot = NSView(frame: NSRect(x: 8, y: 16, width: 10, height: 10))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = isRunning ? NSColor.systemGreen.cgColor : NSColor.tertiaryLabelColor.cgColor
        dot.layer?.cornerRadius = 5
        container.addSubview(dot)

        cell.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cell)
        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 26),
            cell.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < vmNames.count else { return }
        selectedVM = vmNames[row]
        showVM(vmNames[row])
    }

    // MARK: - VM Display

    func showVM(_ machineID: String) {
        if let existing = vmWindows[machineID] {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let stateDir = AgentComputerStore.agentDir(machineID)
        guard FileManager.default.fileExists(atPath: stateDir.path) else { return }

        // Boot the VM
        let controller = VirtualMachineController()
        controllers[machineID] = controller
        bootVM(machineID: machineID, controller: controller)
    }

    private func bootVM(machineID: String, controller: VirtualMachineController) {
        let appSupport = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).standardizedFileURL
        let stateDir = appSupport
            .appendingPathComponent("OPNDRM-VM/AgentComputers/TrustedMacStates", isDirectory: true)
            .appendingPathComponent(machineID, isDirectory: true)

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
        let overlay = OPNDRMVMWindowController(controller: controller, machineName: machineID)
        vmWindows[machineID] = overlay

        controller.setMachine(vm)
        vm.delegate = controller
        controller.start()

        overlay.window?.makeKeyAndOrderFront(nil)
        refreshVMList()
    }

    // MARK: - Actions

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
        // VM creation from IPSW will be implemented in Phase 4
            // For now just create the directory
            let dir = AgentComputerStore.agentDir(name)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        refreshVMList()
        // Future: actually create from IPSW, provision, boot
    }

    @objc private func layoutChanged(_ control: NSSegmentedControl) {
        // Phase 3 will implement multi-VM layout
    }
}
