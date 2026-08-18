import Foundation

/// Manages the OPNDRM VM directory structure for agent VMs.
struct AgentComputerStore {
    static let baseDir: URL = {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: "/tmp")
        return appSupport.appendingPathComponent("OPNDRM-VM/AgentComputers", isDirectory: true)
    }()

    // Legacy path for backward compatibility with older local VM states
    static let legacyBaseDir: URL = {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: "/tmp")
        return appSupport.appendingPathComponent("BuzzBot/AgentComputers", isDirectory: true)
    }()

    static let trustedMacStates = baseDir.appendingPathComponent("TrustedMacStates", isDirectory: true)
    static let legacyTrustedMacStates = legacyBaseDir.appendingPathComponent("TrustedMacStates", isDirectory: true)

    /// Ensure directories exist
    static func ensureDirectories() {
        try? FileManager.default.createDirectory(at: trustedMacStates, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    /// List all agent VMs by their directory names (checks both new and legacy paths)
    static func listMachines() -> [String]
    {
        listAgents()
    }

    static func listAgents() -> [String] {
        var names: [String] = []
        // New path
        if let items = try? FileManager.default.contentsOfDirectory(at: trustedMacStates, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            names.append(contentsOf: items.filter { $0.hasDirectoryPath }.map { $0.lastPathComponent })
        }
        // Legacy path
        if let items = try? FileManager.default.contentsOfDirectory(at: legacyTrustedMacStates, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for item in items where item.hasDirectoryPath {
                let name = item.lastPathComponent
                if !names.contains(name) {
                    names.append(name)
                }
            }
        }
        return names
    }

    /// Get the VM directory for an agent (checks new path first, then legacy)
    static func agentDir(_ name: String) -> URL {
        let newPath = trustedMacStates.appendingPathComponent(name, isDirectory: true)
        if FileManager.default.fileExists(atPath: newPath.appendingPathComponent("Disk.img").path) {
            return newPath
        }
        let legacyPath = legacyTrustedMacStates.appendingPathComponent(name, isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyPath.appendingPathComponent("Disk.img").path) {
            return legacyPath
        }
        // Return new path as default (for new VMs)
        return newPath
    }

    /// Check if a VM has actual state files (not just an empty directory)
    static func hasVMState(_ name: String) -> Bool {
        let dir = agentDir(name)
        switch vmType(name) {
        case .linux:
            return FileManager.default.fileExists(atPath: dir.appendingPathComponent("Disk.img").path)
                && FileManager.default.fileExists(atPath: dir.appendingPathComponent("LinuxKernel").path)
                && FileManager.default.fileExists(atPath: dir.appendingPathComponent("LinuxInitrd").path)
        case .apple:
            return FileManager.default.fileExists(atPath: dir.appendingPathComponent("Disk.img").path)
                && FileManager.default.fileExists(atPath: dir.appendingPathComponent("MachineIdentifier").path)
                && FileManager.default.fileExists(atPath: dir.appendingPathComponent("Lifecycle.plist").path)
                && FileManager.default.fileExists(atPath: dir.appendingPathComponent("AuxiliaryStorage").path)
        }
    }

    /// Determine the VM type. Old VMs without a marker are treated as Apple/macOS VMs.
    static func vmType(_ name: String) -> VMType {
        let dir = agentDir(name)
        let markerURL = dir.appendingPathComponent("vm-type.txt")
        if let raw = try? String(contentsOf: markerURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let type = VMType(rawValue: raw) {
            return type
        }
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("LinuxKernel").path) {
            return .linux
        }
        return .apple
    }

}
