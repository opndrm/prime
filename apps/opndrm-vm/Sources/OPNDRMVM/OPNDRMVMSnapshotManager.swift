import Foundation

@MainActor
final class OPNDRMVMSnapshotManager {
    static let snapshotsBaseDir: URL = {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: "/tmp")
        return appSupport.appendingPathComponent("OPNDRM-VM/Snapshots", isDirectory: true)
    }()

    static func snapshotsDir(for vmName: String) -> URL {
        snapshotsBaseDir.appendingPathComponent(vmName, isDirectory: true)
    }

    static func saveSnapshot(vmName: String, label: String) throws {
        let vmDir = AgentComputerStore.agentDir(vmName)
        let diskURL = vmDir.appendingPathComponent("Disk.img")
        let snapshotDir = snapshotsDir(for: vmName).appendingPathComponent(label, isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destDisk = snapshotDir.appendingPathComponent("Disk.img")
        if FileManager.default.fileExists(atPath: destDisk.path) {
            try FileManager.default.removeItem(at: destDisk)
        }
        try FileManager.default.copyItem(at: diskURL, to: destDisk)
        // Also copy state files
        for file in ["AuxiliaryStorage", "MachineIdentifier", "Lifecycle.plist"] {
            let src = vmDir.appendingPathComponent(file)
            let dst = snapshotDir.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: src.path) {
                if FileManager.default.fileExists(atPath: dst.path) {
                    try FileManager.default.removeItem(at: dst)
                }
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
    }

    static func restoreSnapshot(vmName: String, label: String) throws {
        let vmDir = AgentComputerStore.agentDir(vmName)
        let snapshotDir = snapshotsDir(for: vmName).appendingPathComponent(label, isDirectory: true)
        guard FileManager.default.fileExists(atPath: snapshotDir.path) else {
            throw NSError(domain: "OPNDRMVM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Snapshot not found"])
        }
        for file in ["Disk.img", "AuxiliaryStorage", "MachineIdentifier", "Lifecycle.plist"] {
            let src = snapshotDir.appendingPathComponent(file)
            let dst = vmDir.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: src.path) {
                if FileManager.default.fileExists(atPath: dst.path) {
                    try FileManager.default.removeItem(at: dst)
                }
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
    }

    static func cloneVM(src: String, dst: String) throws {
        let srcDir = AgentComputerStore.agentDir(src)
        let dstDir = AgentComputerStore.agentDir(dst)
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for file in ["Disk.img", "AuxiliaryStorage", "MachineIdentifier", "Lifecycle.plist"] {
            let srcFile = srcDir.appendingPathComponent(file)
            let dstFile = dstDir.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: srcFile.path) {
                try FileManager.default.copyItem(at: srcFile, to: dstFile)
            }
        }
    }

    static func destroyVM(name: String) throws {
        let vmDir = AgentComputerStore.agentDir(name)
        try FileManager.default.removeItem(at: vmDir)
        let snapDir = snapshotsDir(for: name)
        if FileManager.default.fileExists(atPath: snapDir.path) {
            try FileManager.default.removeItem(at: snapDir)
        }
    }

    static func listSnapshots(vmName: String) -> [String] {
        let dir = snapshotsDir(for: vmName)
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        return items.filter { $0.hasDirectoryPath }.map { $0.lastPathComponent }
    }
}
