import AppKit
import Darwin
import Foundation
@preconcurrency import Virtualization

private struct UnsafeTransfer<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

struct OPNDRMPreparedVM {
    let controller: VirtualMachineController
    let view: VZVirtualMachineView
}

struct OPNDRMVMCreateProgress {
    let phase: String
    let fraction: Double?
    let detail: String
    let canCancel: Bool
}

enum VMType: String {
    case apple
    case linux
}

@MainActor
final class OPNDRMVMCreator: NSObject {
    static let shared = OPNDRMVMCreator()

    private static let downloadCacheDir: URL = {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: "/tmp")
        return appSupport.appendingPathComponent("OPNDRM-VM/Downloads", isDirectory: true)
    }()

    private let alpineBaseURL = "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/netboot"
    private var currentDownloadTask: URLSessionDownloadTask?
    private weak var currentInstallProgress: Progress?

    // MARK: - Public create/load API

    func cancelActiveOperation() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        currentInstallProgress?.cancel()
        currentInstallProgress = nil
    }

    func createAppleVM(
        name: String,
        memoryGB: Int,
        diskGB: Int = 96,
        onProgress: ((OPNDRMVMCreateProgress) -> Void)? = nil,
        onPrepared: ((OPNDRMPreparedVM) -> Void)? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let completionBox = UnsafeTransfer(completion)
        let onPreparedBox = UnsafeTransfer(onPrepared)
        let onProgressBox = UnsafeTransfer(onProgress)

        onProgressBox.value?(OPNDRMVMCreateProgress(
            phase: "Preparing macOS download",
            fraction: nil,
            detail: "macOS needs a one-time 12–15GB IPSW. Linux Quick Start is much faster.",
            canCancel: true
        ))

        fetchLocalRestoreImage(onProgress: onProgress) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completionBox.value(.failure(error))
            case .success(let payload):
                do {
                    onProgressBox.value?(OPNDRMVMCreateProgress(
                        phase: "Creating macOS VM files",
                        fraction: nil,
                        detail: "Creating disk, machine identifier, and auxiliary storage for \(name)…",
                        canCancel: false
                    ))
                    let prepared = try self.prepareMacInstallerVM(
                        name: name,
                        restoreImage: payload.restoreImage,
                        restoreImageURL: payload.localURL,
                        memoryGB: memoryGB,
                        diskGB: diskGB
                    )
                    onPreparedBox.value?(prepared.vm)
                    FileHandle.standardError.write(Data("OPNDRMVM: starting macOS install for \(name) from \(payload.localURL.path)\n".utf8))

                    let installProgress = prepared.installer.progress
                    self.currentInstallProgress = installProgress
                    onProgressBox.value?(OPNDRMVMCreateProgress(
                        phase: "Installing macOS",
                        fraction: nil,
                        detail: "Virtualization installer is running from the local IPSW. This can take a while; future clones avoid this setup.",
                        canCancel: true
                    ))

                    prepared.installer.install { installResult in
                        let resultBox = UnsafeTransfer(installResult)
                        DispatchQueue.main.async {
                            self.currentInstallProgress = nil
                            switch resultBox.value {
                            case .success:
                                FileHandle.standardError.write(Data("OPNDRMVM: macOS install completed for \(name)\n".utf8))
                                onProgressBox.value?(OPNDRMVMCreateProgress(
                                    phase: "macOS VM ready",
                                    fraction: 1,
                                    detail: "\(name) is ready to boot.",
                                    canCancel: false
                                ))
                                completionBox.value(.success(()))
                            case .failure(let error):
                                FileHandle.standardError.write(Data("OPNDRMVM: macOS install failed for \(name): \(error.localizedDescription)\n".utf8))
                                completionBox.value(.failure(error))
                            }
                        }
                    }
                } catch {
                    completionBox.value(.failure(error))
                }
            }
        }
    }

    func createLinuxVM(
        name: String,
        memoryGB: Int,
        diskGB: Int = 32,
        onProgress: ((OPNDRMVMCreateProgress) -> Void)? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let completionBox = UnsafeTransfer(completion)
        let onProgressBox = UnsafeTransfer(onProgress)
        let kernelURL = URL(string: "\(alpineBaseURL)/vmlinuz-virt")!
        let initrdURL = URL(string: "\(alpineBaseURL)/initramfs-virt")!

        onProgressBox.value?(OPNDRMVMCreateProgress(
            phase: "Linux Quick Start",
            fraction: nil,
            detail: "Downloading small Alpine ARM64 boot files…",
            canCancel: true
        ))

        downloadIfNeeded(
            from: kernelURL,
            fileName: "alpine-aarch64-vmlinuz-virt",
            phase: "Downloading Linux kernel",
            onProgressBox: onProgressBox
        ) { [weak self] kernelResult in
            guard let self else { return }
            switch kernelResult {
            case .failure(let error):
                completionBox.value(.failure(error))
            case .success(let localKernel):
                self.downloadIfNeeded(
                    from: initrdURL,
                    fileName: "alpine-aarch64-initramfs-virt",
                    phase: "Downloading Linux initrd",
                    onProgressBox: onProgressBox
                ) { initrdResult in
                    switch initrdResult {
                    case .failure(let error):
                        completionBox.value(.failure(error))
                    case .success(let localInitrd):
                        do {
                            onProgressBox.value?(OPNDRMVMCreateProgress(
                                phase: "Creating Linux VM",
                                fraction: nil,
                                detail: "Creating disk and boot configuration for \(name)…",
                                canCancel: false
                            ))
                            try self.writeLinuxVMState(name: name, memoryGB: memoryGB, diskGB: diskGB, kernelURL: localKernel, initrdURL: localInitrd)
                            onProgressBox.value?(OPNDRMVMCreateProgress(
                                phase: "Linux VM ready",
                                fraction: 1,
                                detail: "\(name) is ready to boot.",
                                canCancel: false
                            ))
                            completionBox.value(.success(()))
                        } catch {
                            completionBox.value(.failure(error))
                        }
                    }
                }
            }
        }
    }

    func loadExistingVM(name: String) throws -> OPNDRMPreparedVM {
        switch AgentComputerStore.vmType(name) {
        case .linux:
            return try loadLinuxVM(name: name)
        case .apple:
            return try loadMacVM(name: name)
        }
    }

    // MARK: - macOS restore image download

    private func fetchLocalRestoreImage(
        onProgress: ((OPNDRMVMCreateProgress) -> Void)?,
        completion: @escaping (Result<(restoreImage: VZMacOSRestoreImage, localURL: URL), Error>) -> Void
    ) {
        let completionBox = UnsafeTransfer(completion)
        let onProgressBox = UnsafeTransfer(onProgress)
        try? FileManager.default.createDirectory(at: Self.downloadCacheDir, withIntermediateDirectories: true)
        FileHandle.standardError.write(Data("OPNDRMVM: fetching latest supported macOS restore image metadata...\n".utf8))

        onProgressBox.value?(OPNDRMVMCreateProgress(
            phase: "Finding latest supported macOS IPSW",
            fraction: nil,
            detail: "Asking Apple for the latest restore image supported by this Mac…",
            canCancel: true
        ))

        VZMacOSRestoreImage.fetchLatestSupported { [weak self] result in
            let resultBox = UnsafeTransfer(result)
            DispatchQueue.main.async {
                guard let self else { return }
                switch resultBox.value {
                case .failure(let error):
                    completionBox.value(.failure(error))
                case .success(let networkImage):
                    let sourceURL = networkImage.url
                    let version = "\(networkImage.operatingSystemVersion.majorVersion).\(networkImage.operatingSystemVersion.minorVersion).\(networkImage.operatingSystemVersion.patchVersion)"
                    let fileName = "macOS-\(version)-\(networkImage.buildVersion).ipsw"
                    self.downloadIfNeeded(
                        from: sourceURL,
                        fileName: fileName,
                        phase: "Downloading macOS IPSW",
                        onProgressBox: onProgressBox
                    ) { localResult in
                        switch localResult {
                        case .failure(let error):
                            completionBox.value(.failure(error))
                        case .success(let localURL):
                            onProgressBox.value?(OPNDRMVMCreateProgress(
                                phase: "Loading macOS restore image",
                                fraction: nil,
                                detail: "Validating downloaded IPSW…",
                                canCancel: false
                            ))
                            VZMacOSRestoreImage.load(from: localURL) { loadResult in
                                let loadResultBox = UnsafeTransfer(loadResult)
                                DispatchQueue.main.async {
                                    switch loadResultBox.value {
                                    case .failure(let error):
                                        completionBox.value(.failure(error))
                                    case .success(let localImage):
                                        completionBox.value(.success((restoreImage: localImage, localURL: localURL)))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func downloadIfNeeded(
        from sourceURL: URL,
        fileName: String,
        phase: String,
        onProgressBox: UnsafeTransfer<((OPNDRMVMCreateProgress) -> Void)?>,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let completionBox = UnsafeTransfer(completion)
        try? FileManager.default.createDirectory(at: Self.downloadCacheDir, withIntermediateDirectories: true)
        let destinationURL = Self.downloadCacheDir.appendingPathComponent(fileName)

        if let attrs = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
           let size = attrs[.size] as? NSNumber,
           size.int64Value > 0 {
            onProgressBox.value?(OPNDRMVMCreateProgress(
                phase: phase,
                fraction: 1,
                detail: "Using cached \(Self.byteString(size.int64Value)) file: \(fileName)",
                canCancel: false
            ))
            completionBox.value(.success(destinationURL))
            return
        }

        FileHandle.standardError.write(Data("OPNDRMVM: downloading \(sourceURL.absoluteString) -> \(destinationURL.path)\n".utf8))
        onProgressBox.value?(OPNDRMVMCreateProgress(
            phase: phase,
            fraction: 0,
            detail: "Starting download: \(fileName)",
            canCancel: true
        ))

        let task = URLSession.shared.downloadTask(with: sourceURL) { [weak self] temporaryURL, _, error in
            // Important: CFNetwork owns the temporary file only for the duration
            // of this completion callback. Move it to our cache synchronously
            // before dispatching back to the main actor; otherwise the temp file
            // may be deleted and FileManager.moveItem will fail.
            let result: Result<URL, Error>
            if let error {
                result = .failure(error)
            } else if let temporaryURL {
                do {
                    try? FileManager.default.removeItem(at: destinationURL)
                    try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                    result = .success(destinationURL)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(Self.error("Download failed: no temporary file"))
            }

            let resultBox = UnsafeTransfer(result)
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentDownloadTask = nil
                switch resultBox.value {
                case .success(let url):
                    onProgressBox.value?(OPNDRMVMCreateProgress(
                        phase: phase,
                        fraction: 1,
                        detail: "Downloaded \(fileName)",
                        canCancel: false
                    ))
                    completionBox.value(.success(url))
                case .failure(let error):
                    completionBox.value(.failure(error))
                }
            }
        }
        currentDownloadTask = task

        let progress = task.progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if progress.isCancelled || progress.isFinished {
                timer.invalidate()
                return
            }
            onProgressBox.value?(OPNDRMVMCreateProgress(
                phase: phase,
                fraction: progress.totalUnitCount > 0 ? progress.fractionCompleted : nil,
                detail: Self.percentDetail(prefix: "Downloading \(fileName)", progress: progress),
                canCancel: true
            ))
        }
        timer.tolerance = 0.2
        task.resume()
    }

    // MARK: - macOS VM creation/loading

    private func prepareMacInstallerVM(
        name: String,
        restoreImage: VZMacOSRestoreImage,
        restoreImageURL: URL,
        memoryGB: Int,
        diskGB: Int
    ) throws -> (vm: OPNDRMPreparedVM, installer: VZMacOSInstaller) {
        guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
            throw Self.error("This host does not support the latest macOS restore image.")
        }

        let stateDir = AgentComputerStore.trustedMacStates.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        let diskURL = stateDir.appendingPathComponent("Disk.img")
        let auxURL = stateDir.appendingPathComponent("AuxiliaryStorage")
        let machineIDURL = stateDir.appendingPathComponent("MachineIdentifier")
        let lifecycleURL = stateDir.appendingPathComponent("Lifecycle.plist")
        let infoURL = stateDir.appendingPathComponent("VMInfo.plist")

        try createSparseRawDisk(at: diskURL, sizeGB: diskGB, overwrite: true)

        let hardwareModel = requirements.hardwareModel
        let machineIdentifier = VZMacMachineIdentifier()
        let auxiliaryStorage = try VZMacAuxiliaryStorage(
            creatingStorageAt: auxURL,
            hardwareModel: hardwareModel,
            options: [.allowOverwrite]
        )

        try machineIdentifier.dataRepresentation.write(to: machineIDURL)
        try writePlist(["hardwareModelData": hardwareModel.dataRepresentation], to: lifecycleURL)
        try writePlist([
            "type": VMType.apple.rawValue,
            "memoryGB": memoryGB,
            "diskGB": diskGB,
            "cpuCount": max(Int(requirements.minimumSupportedCPUCount), 4),
            "createdAt": Date()
        ], to: infoURL)
        try VMType.apple.rawValue.write(to: stateDir.appendingPathComponent("vm-type.txt"), atomically: true, encoding: .utf8)

        let config = try makeMacConfiguration(
            diskURL: diskURL,
            auxiliaryStorage: auxiliaryStorage,
            hardwareModel: hardwareModel,
            machineIdentifier: machineIdentifier,
            cpuCount: max(Int(requirements.minimumSupportedCPUCount), 4),
            memorySize: max(UInt64(memoryGB) * 1024 * 1024 * 1024, requirements.minimumSupportedMemorySize)
        )

        let vm = VZVirtualMachine(configuration: config)
        let controller = VirtualMachineController()
        controller.setMachine(vm)
        vm.delegate = controller
        let view = VZVirtualMachineView()
        view.virtualMachine = vm
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: restoreImageURL)
        return (OPNDRMPreparedVM(controller: controller, view: view), installer)
    }

    private func loadMacVM(name: String) throws -> OPNDRMPreparedVM {
        let stateDir = AgentComputerStore.agentDir(name)
        let diskURL = stateDir.appendingPathComponent("Disk.img")
        let auxURL = stateDir.appendingPathComponent("AuxiliaryStorage")
        let machineIDURL = stateDir.appendingPathComponent("MachineIdentifier")
        let lifecycleURL = stateDir.appendingPathComponent("Lifecycle.plist")

        guard FileManager.default.fileExists(atPath: diskURL.path) else { throw Self.error("Missing Disk.img for \(name)") }
        guard FileManager.default.fileExists(atPath: auxURL.path) else { throw Self.error("Missing AuxiliaryStorage for \(name)") }
        guard let machineIdentifierData = try? Data(contentsOf: machineIDURL),
              let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            throw Self.error("Missing or invalid MachineIdentifier for \(name)")
        }
        guard let lifecycleData = try? Data(contentsOf: lifecycleURL),
              let plist = try? PropertyListSerialization.propertyList(from: lifecycleData, options: [], format: nil) as? [String: Any],
              let hardwareModelData = plist["hardwareModelData"] as? Data,
              let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData),
              hardwareModel.isSupported else {
            throw Self.error("Missing or unsupported hardware model for \(name)")
        }

        let auxiliaryStorage = VZMacAuxiliaryStorage(url: auxURL)
        let config = try makeMacConfiguration(
            diskURL: diskURL,
            auxiliaryStorage: auxiliaryStorage,
            hardwareModel: hardwareModel,
            machineIdentifier: machineIdentifier,
            cpuCount: 4,
            memorySize: 8 * 1024 * 1024 * 1024
        )

        let vm = VZVirtualMachine(configuration: config)
        let controller = VirtualMachineController()
        controller.setMachine(vm)
        vm.delegate = controller
        let view = VZVirtualMachineView()
        view.virtualMachine = vm
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return OPNDRMPreparedVM(controller: controller, view: view)
    }

    private func makeMacConfiguration(
        diskURL: URL,
        auxiliaryStorage: VZMacAuxiliaryStorage,
        hardwareModel: VZMacHardwareModel,
        machineIdentifier: VZMacMachineIdentifier,
        cpuCount: Int,
        memorySize: UInt64
    ) throws -> VZVirtualMachineConfiguration {
        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardwareModel
        platform.machineIdentifier = machineIdentifier
        platform.auxiliaryStorage = auxiliaryStorage

        let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
        let config = VZVirtualMachineConfiguration()
        config.cpuCount = cpuCount
        config.memorySize = memorySize
        config.platform = platform
        config.bootLoader = VZMacOSBootLoader()
        config.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]

        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1080, pixelsPerInch: 80)]
        config.graphicsDevices = [graphics]
        config.keyboards = [VZMacKeyboardConfiguration()]
        config.pointingDevices = [VZMacTrackpadConfiguration()]

        let networkConfig = VZVirtioNetworkDeviceConfiguration()
        networkConfig.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [networkConfig]
        config.socketDevices = [VZVirtioSocketDeviceConfiguration()]

        let audioConfig = VZVirtioSoundDeviceConfiguration()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        audioConfig.streams = [outputStream]
        config.audioDevices = [audioConfig]

        try config.validate()
        return config
    }

    // MARK: - Linux VM creation/loading

    private func writeLinuxVMState(name: String, memoryGB: Int, diskGB: Int, kernelURL: URL, initrdURL: URL) throws {
        let stateDir = AgentComputerStore.trustedMacStates.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        let diskURL = stateDir.appendingPathComponent("Disk.img")
        try createSparseRawDisk(at: diskURL, sizeGB: diskGB, overwrite: true)

        let localKernel = stateDir.appendingPathComponent("LinuxKernel")
        let localKernelSource = stateDir.appendingPathComponent("LinuxKernelSource")
        let localInitrd = stateDir.appendingPathComponent("LinuxInitrd")
        try? FileManager.default.removeItem(at: localKernel)
        try? FileManager.default.removeItem(at: localKernelSource)
        try? FileManager.default.removeItem(at: localInitrd)
        try FileManager.default.copyItem(at: kernelURL, to: localKernelSource)
        try writeBootableLinuxKernel(from: kernelURL, to: localKernel)
        try FileManager.default.copyItem(at: initrdURL, to: localInitrd)

        let machineIdentifier = VZGenericMachineIdentifier()
        try machineIdentifier.dataRepresentation.write(to: stateDir.appendingPathComponent("GenericMachineIdentifier"))

        let commandLine = "console=tty0 console=hvc0 modules=loop,squashfs,sd-mod,usb-storage,virtio_blk,virtio_net,virtio_gpu modloop=\(alpineBaseURL)/modloop-virt alpine_repo=https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/"
        try commandLine.write(to: stateDir.appendingPathComponent("LinuxCommandLine"), atomically: true, encoding: .utf8)
        try VMType.linux.rawValue.write(to: stateDir.appendingPathComponent("vm-type.txt"), atomically: true, encoding: .utf8)
        try writePlist([
            "type": VMType.linux.rawValue,
            "memoryGB": memoryGB,
            "diskGB": diskGB,
            "cpuCount": 2,
            "createdAt": Date()
        ], to: stateDir.appendingPathComponent("VMInfo.plist"))
    }

    private func loadLinuxVM(name: String) throws -> OPNDRMPreparedVM {
        let stateDir = AgentComputerStore.agentDir(name)
        let diskURL = stateDir.appendingPathComponent("Disk.img")
        let kernelURL = stateDir.appendingPathComponent("LinuxKernel")
        let initrdURL = stateDir.appendingPathComponent("LinuxInitrd")
        let commandLineURL = stateDir.appendingPathComponent("LinuxCommandLine")
        let machineIDURL = stateDir.appendingPathComponent("GenericMachineIdentifier")

        guard FileManager.default.fileExists(atPath: diskURL.path) else { throw Self.error("Missing Disk.img for \(name)") }
        guard FileManager.default.fileExists(atPath: kernelURL.path) else { throw Self.error("Missing LinuxKernel for \(name)") }
        guard FileManager.default.fileExists(atPath: initrdURL.path) else { throw Self.error("Missing LinuxInitrd for \(name)") }
        try ensureLinuxKernelIsBootable(at: kernelURL)

        let platform = VZGenericPlatformConfiguration()
        if let machineIdentifierData = try? Data(contentsOf: machineIDURL),
           let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) {
            platform.machineIdentifier = machineIdentifier
        } else {
            let machineIdentifier = VZGenericMachineIdentifier()
            platform.machineIdentifier = machineIdentifier
            try? machineIdentifier.dataRepresentation.write(to: machineIDURL)
        }

        let bootLoader = VZLinuxBootLoader(kernelURL: kernelURL)
        bootLoader.initialRamdiskURL = initrdURL
        bootLoader.commandLine = (try? String(contentsOf: commandLineURL, encoding: .utf8)) ?? "console=tty0 console=hvc0"

        let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
        let disk = VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
        disk.blockDeviceIdentifier = "opndrm-linux"

        let config = VZVirtualMachineConfiguration()
        config.platform = platform
        config.bootLoader = bootLoader
        config.cpuCount = 2
        config.memorySize = 4 * 1024 * 1024 * 1024
        config.storageDevices = [disk]

        let graphics = VZVirtioGraphicsDeviceConfiguration()
        graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 800)]
        config.graphicsDevices = [graphics]
        config.keyboards = [VZUSBKeyboardConfiguration()]
        config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

        let networkConfig = VZVirtioNetworkDeviceConfiguration()
        networkConfig.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [networkConfig]
        config.socketDevices = [VZVirtioSocketDeviceConfiguration()]
        config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        config.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

        try config.validate()

        let vm = VZVirtualMachine(configuration: config)
        let controller = VirtualMachineController()
        controller.setMachine(vm)
        vm.delegate = controller
        let view = VZVirtualMachineView()
        view.virtualMachine = vm
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return OPNDRMPreparedVM(controller: controller, view: view)
    }

    // MARK: - Helpers

    private func ensureLinuxKernelIsBootable(at kernelURL: URL) throws {
        let data = try Data(contentsOf: kernelURL, options: [.mappedIfSafe])
        guard Self.gzipPayloadOffset(in: data) != nil else { return }
        let temporaryURL = kernelURL.deletingLastPathComponent()
            .appendingPathComponent("LinuxKernel.uncompressed")
        try? FileManager.default.removeItem(at: temporaryURL)
        try writeBootableLinuxKernel(from: kernelURL, to: temporaryURL)
        try FileManager.default.removeItem(at: kernelURL)
        try FileManager.default.moveItem(at: temporaryURL, to: kernelURL)
    }

    private func writeBootableLinuxKernel(from sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard let offset = Self.gzipPayloadOffset(in: data) else {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
            return
        }

        let gzipPayload = data.subdata(in: offset..<data.endIndex)
        let tempGzip = FileManager.default.temporaryDirectory
            .appendingPathComponent("opndrm-linux-kernel-\(UUID().uuidString).gz")
        try gzipPayload.write(to: tempGzip, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempGzip) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-dc", tempGzip.path]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard !output.isEmpty else {
            let detail = String(data: stderr, encoding: .utf8) ?? "gzip failed"
            throw Self.error("Could not extract bootable Linux kernel image: \(detail)")
        }
        if process.terminationStatus != 0 {
            let detail = String(data: stderr, encoding: .utf8) ?? ""
            let toleratedTrailingGarbage = detail.localizedCaseInsensitiveContains("trailing garbage ignored")
            guard toleratedTrailingGarbage else {
                throw Self.error("Could not extract bootable Linux kernel image: \(detail)")
            }
        }
        try output.write(to: destinationURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
    }

    nonisolated private static func gzipPayloadOffset(in data: Data) -> Data.Index? {
        let magic = Data([0x1f, 0x8b, 0x08])
        return data.range(of: magic)?.lowerBound
    }

    private func createSparseRawDisk(at url: URL, sizeGB: Int, overwrite: Bool) throws {
        if overwrite { try? FileManager.default.removeItem(at: url) }
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw Self.error("Cannot create disk image at \(url.path)")
        }
        let fd = open(url.path, O_RDWR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        let bytes = off_t(sizeGB) * 1024 * 1024 * 1024
        guard ftruncate(fd, bytes) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private func writePlist(_ plist: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try data.write(to: url)
    }

    nonisolated private static func percentDetail(prefix: String, progress: Progress) -> String {
        let complete = progress.completedUnitCount
        let total = progress.totalUnitCount
        if total > 0 {
            let pct = max(0, min(100, progress.fractionCompleted * 100))
            return String(format: "%@ — %.0f%% (%@ / %@)", prefix, pct, byteString(complete), byteString(total))
        }
        if complete > 0 {
            return "\(prefix) — \(byteString(complete))"
        }
        return prefix
    }

    nonisolated private static func byteString(_ bytes: Int64) -> String {
        let value = Double(bytes)
        if value >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", value / (1024 * 1024 * 1024))
        }
        if value >= 1024 * 1024 {
            return String(format: "%.1f MB", value / (1024 * 1024))
        }
        if value >= 1024 {
            return String(format: "%.1f KB", value / 1024)
        }
        return "\(bytes) B"
    }

    nonisolated private static func error(_ message: String) -> NSError {
        NSError(domain: "OPNDRMVM", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
