import AppKit
import Foundation
import Network
@preconcurrency import Virtualization

@main
@MainActor
final class OPNDRMVMApp: NSObject, NSApplicationDelegate, OPNDRMVMSocketDelegate {
    var controller: VirtualMachineController?
    var overlayController: OPNDRMVMWindowController?
    private var socketServer: OPNDRMVMSocketServer?
    private var terminationAwaitingOrderlyStop = false

    static func main() {
        let application = NSApplication.shared
        let delegate = OPNDRMVMApp()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = Array(CommandLine.arguments.dropFirst())
        var machineID: String?
        var i = 0
        while i < args.count {
            if args[i] == "--machine" && i + 1 < args.count {
                machineID = args[i + 1]
                i += 2
            } else if args[i].hasPrefix("--machine=") {
                machineID = String(args[i].dropFirst("--machine=".count))
                i += 1
            } else { i += 1 }
        }
        guard let machineID, !machineID.isEmpty else {
            FileHandle.standardError.write(Data("Usage: opndrm-vm --machine <machine-id>\n".utf8))
            NSApp.terminate(nil)
            return
        }

        // Boot VM directly
        bootVM(machineID: machineID)

        // Start socket server for CLI communication
        socketServer = OPNDRMVMSocketServer(delegate: self)
        socketServer?.start(port: 7777)
        FileHandle.standardError.write(Data("OPNDRMVM: socket server listening on port 7777\n".utf8))
    }

    private func bootVM(machineID: String) {
        let appSupport = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).standardizedFileURL
        let stateDir = appSupport
            .appendingPathComponent("OPNDRM-VM/AgentComputers/TrustedMacStates", isDirectory: true)
            .appendingPathComponent(machineID, isDirectory: true)

        guard FileManager.default.fileExists(atPath: stateDir.path) else {
            FileHandle.standardError.write(Data("OPNDRMVM: machine \(machineID) not found\n".utf8))
            NSApp.terminate(nil)
            return
        }

        let diskURL = stateDir.appendingPathComponent("Disk.img")
        let auxURL = stateDir.appendingPathComponent("AuxiliaryStorage")
        let machineIDURL = stateDir.appendingPathComponent("MachineIdentifier")
        let lifecycleURL = stateDir.appendingPathComponent("Lifecycle.plist")

        guard let machineIdentifierData = try? Data(contentsOf: machineIDURL),
              let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            FileHandle.standardError.write(Data("OPNDRMVM: invalid MachineIdentifier\n".utf8))
            NSApp.terminate(nil)
            return
        }

        guard let lifecycleData = try? Data(contentsOf: lifecycleURL),
              let plist = try? PropertyListSerialization.propertyList(from: lifecycleData, options: [], format: nil) as? [String: Any],
              let hardwareModelData = plist["hardwareModelData"] as? Data,
              let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData),
              hardwareModel.isSupported else {
            FileHandle.standardError.write(Data("OPNDRMVM: invalid hardware model\n".utf8))
            NSApp.terminate(nil)
            return
        }

        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardwareModel
        platform.machineIdentifier = machineIdentifier
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url: auxURL)

        let diskAttachment = try! VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)

        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = 4
        configuration.memorySize = 8 * 1024 * 1024 * 1024
        configuration.platform = platform
        configuration.bootLoader = VZMacOSBootLoader()
        configuration.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200, pixelsPerInch: 80)]
        configuration.graphicsDevices = [graphics]
        configuration.keyboards = [VZMacKeyboardConfiguration()]
        configuration.pointingDevices = [VZMacTrackpadConfiguration()]

        let networkConfig = VZVirtioNetworkDeviceConfiguration()
        networkConfig.attachment = VZNATNetworkDeviceAttachment()
        configuration.networkDevices = [networkConfig]

        // Virtio socket device for host<->guest command bridge.
        // Only one virtio socket device per VM; the guest helper listens on port 2222.
        configuration.socketDevices = [VZVirtioSocketDeviceConfiguration()]

        try! configuration.validate()

        let virtualMachine = VZVirtualMachine(configuration: configuration)
        let controller = VirtualMachineController()
        self.controller = controller

        let overlay = OPNDRMVMWindowController(controller: controller, machineName: machineID)
        overlayController = overlay

        controller.setMachine(virtualMachine)
        virtualMachine.delegate = controller

        FileHandle.standardError.write(Data("OPNDRMVM: booting \(machineID)...\n".utf8))
        controller.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        if controller.requestOrderlyStopForTermination() { return .terminateNow }
        terminationAwaitingOrderlyStop = true
        return .terminateCancel
    }
}

// MARK: - Socket Server for CLI communication

@MainActor
protocol OPNDRMVMSocketDelegate: AnyObject {
    var controller: VirtualMachineController? { get }
    var overlayController: OPNDRMVMWindowController? { get }
}

@MainActor
final class OPNDRMVMSocketServer {
    private var listener: NWListener?
    private let port: UInt16
    private let delegate: OPNDRMVMSocketDelegate

    init(delegate: OPNDRMVMSocketDelegate, port: UInt16 = 7777) {
        self.delegate = delegate
        self.port = port
    }

    func start(port: UInt16) {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: port))
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in self?.handleConnection(connection) }
            }
            listener.start(queue: DispatchQueue.main)
            self.listener = listener
        } catch {
            FileHandle.standardError.write(Data("OPNDRMVM: socket server failed: \(error)\n".utf8))
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global())
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data: Data?, _: NWConnection.ContentContext?, _: Bool, error: NWError?) in
            guard let data, let cmd = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                connection.cancel()
                return
            }
            Task { @MainActor [weak self] in
                let response = self?.handleCommand(cmd) ?? "error: no server"
                let responseData = response.data(using: .utf8) ?? Data()
                connection.send(content: responseData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func handleCommand(_ cmd: String) -> String {
        let parts = cmd.split(separator: " ", maxSplits: 1)
        let action = String(parts[0])
        
        switch action {
        case "show":
            overlayController?.focusVM()
            return "ok: showing VM"
        case "focus":
            overlayController?.focusVM()
            return "ok: focused VM"
        case "key":
            guard let rest = parts.last, !rest.isEmpty else { return "error: key requires <keycode>[,flags]" }
            let keyParts = rest.split(separator: ",")
            guard let first = keyParts.first, let keyCode = UInt16(first) else { return "error: bad keycode" }
            var flags: CGEventFlags = []
            if keyParts.count > 1 {
                let mods = String(keyParts[1])
                if mods.contains("C") { flags.insert(.maskControl) }
                if mods.contains("S") { flags.insert(.maskShift) }
                if mods.contains("A") { flags.insert(.maskAlternate) }
                if mods.contains("M") { flags.insert(.maskCommand) }
            }
            overlayController?.postKey(keyCode: keyCode, flags: flags)
            return "ok: key sent"
        case "hide":
            overlayController?.window?.orderOut(nil)
            return "ok: hidden"
        case "stop":
            controller?.stop()
            return "ok: stopping"
        case "status":
            let state = controller?.lifecycle.rawValue ?? "unknown"
            let status = controller?.statusText ?? ""
            return "ok: \(state) | \(status)"
        case "ping":
            return "ok: pong"
        default:
            return "error: unknown command \(action)"
        }
    }

    private var overlayController: OPNDRMVMWindowController? {
        delegate.overlayController
    }
    private var controller: VirtualMachineController? {
        delegate.controller
    }
}
