import Foundation

/// Manages the BuzzBot directory structure for agent VMs.
struct AgentComputerStore {
    static let baseDir: URL = {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: "/tmp")
        return appSupport.appendingPathComponent("OPNDRM-VM/AgentComputers", isDirectory: true)
    }()

    static let trustedMacStates = baseDir.appendingPathComponent("TrustedMacStates", isDirectory: true)

    /// Ensure directories exist
    static func ensureDirectories() {
        try? FileManager.default.createDirectory(at: trustedMacStates, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    /// List all agent VMs by their directory names
    static func listAgents() -> [String] {
        guard let items = try? FileManager.default.contentsOfDirectory(at: trustedMacStates, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        return items.filter { $0.hasDirectoryPath }.map { $0.lastPathComponent }
    }

    /// Check if an agent VM exists
    static func agentExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: trustedMacStates.appendingPathComponent(name).path)
    }

    /// Get the VM directory for an agent
    static func agentDir(_ name: String) -> URL {
        trustedMacStates.appendingPathComponent(name, isDirectory: true)
    }
}
