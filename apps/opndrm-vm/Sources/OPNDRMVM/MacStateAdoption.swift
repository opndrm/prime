import Foundation
@preconcurrency import Virtualization

/// Loads VM files from the trusted state directory with stat-based verification.
/// No hashing of large files. No authorization chain.
enum MacStateLoader {
    /// Verify that the VM state directory contains the required files.
    static func verifyStateDir(_ dir: URL) -> Bool {
        let required = ["Disk.img", "AuxiliaryStorage", "MachineIdentifier", "Lifecycle.plist"]
        for name in required {
            let path = dir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: path.path) else {
                FileHandle.standardError.write(Data("OPNDRMVM: missing \(name)\n".utf8))
                return false
            }
        }
        return true
    }

    /// Read the lifecycle plist for hardware model info
    static func readLifecycle(_ dir: URL) -> [String: Any]? {
        let path = dir.appendingPathComponent("Lifecycle.plist")
        guard let data = try? Data(contentsOf: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
}
