import Foundation

struct VMDiskUsage {
    let vmName: String
    let diskSize: Int64
    let snapshotSize: Int64
    var totalSize: Int64 { diskSize + snapshotSize }
}

struct DiskUsageReport {
    let vms: [VMDiskUsage]
    let totalUsed: Int64
    let totalAvailable: Int64
}

@MainActor
final class OPNDRMVMDiskManager {
    static func calculateDiskUsage() -> DiskUsageReport {
        let vmNames = AgentComputerStore.listAgents()
        var usages: [VMDiskUsage] = []

        for name in vmNames {
            let diskSize = directorySize(AgentComputerStore.agentDir(name))
            let snapshotSize = directorySize(OPNDRMVMSnapshotManager.snapshotsDir(for: name))
            usages.append(VMDiskUsage(vmName: name, diskSize: diskSize, snapshotSize: snapshotSize))
        }

        let totalUsed = usages.reduce(0) { $0 + $1.totalSize }
        let availableURL = URL(fileURLWithPath: "/")
        let attrs = try? FileManager.default.attributesOfItem(atPath: availableURL.path)
        let totalAvailable = (attrs?[.systemFreeSize] as? Int64) ?? 0

        return DiskUsageReport(vms: usages, totalUsed: totalUsed, totalAvailable: totalAvailable)
    }

    static func cleanOldSnapshots(vmName: String, keepLatest: Int) throws {
        let snapshots = OPNDRMVMSnapshotManager.listSnapshots(vmName: vmName).sorted()
        guard snapshots.count > keepLatest else { return }
        let toRemove = snapshots.prefix(snapshots.count - keepLatest)
        for snap in toRemove {
            let dir = OPNDRMVMSnapshotManager.snapshotsDir(for: vmName).appendingPathComponent(snap)
            try FileManager.default.removeItem(at: dir)
        }
    }

    private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
