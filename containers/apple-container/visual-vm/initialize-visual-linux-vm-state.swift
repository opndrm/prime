import Foundation
import Virtualization

// Native, no-launch initializer for one already-authorized visual VM bundle.
// It creates only VM-local storage state. It never creates or starts a VM.
enum VisualVMStateInitializer {
    static let diskName = "guest-installation-disk.raw"
    static let efiName = "efi-variable-store.bin"
    static let identityName = "generic-machine-identifier.bin"

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data(("Visual VM native state initialization refused: \(message)\n").utf8))
        exit(1)
    }

    static func requiredValue(_ flag: String, from arguments: [String]) -> String {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            fail("missing \(flag)")
        }
        return arguments[index + 1]
    }

    static func regularChild(named name: String, of bundle: URL) -> URL {
        let child = bundle.appendingPathComponent(name, isDirectory: false)
        guard child.deletingLastPathComponent().standardizedFileURL == bundle.standardizedFileURL else {
            fail("state artifact path escaped the approved bundle")
        }
        guard !FileManager.default.fileExists(atPath: child.path) else {
            fail("state artifact already exists: \(name)")
        }
        return child
    }

    static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 4, arguments[0] == "--bundle", arguments[2] == "--disk-bytes" else {
            fail("usage is --bundle <owner-only-new-bundle> --disk-bytes <positive-integer>")
        }
        let bundle = URL(fileURLWithPath: requiredValue("--bundle", from: arguments), isDirectory: true).standardizedFileURL
        guard bundle.path.hasPrefix("/") else { fail("bundle must be an absolute local path") }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bundle.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            fail("approved bundle directory is missing")
        }
        let bundleValues = try bundle.resourceValues(forKeys: [.isSymbolicLinkKey, .isWritableKey])
        guard bundleValues.isSymbolicLink != true, bundleValues.isWritable == true else {
            fail("approved bundle is not a writable non-symlink directory")
        }
        guard let diskSize = UInt64(requiredValue("--disk-bytes", from: arguments)), diskSize >= 32 * 1024 * 1024 * 1024 else {
            fail("disk size must be at least 32 GiB")
        }

        let disk = regularChild(named: diskName, of: bundle)
        let efi = regularChild(named: efiName, of: bundle)
        let identity = regularChild(named: identityName, of: bundle)

        guard FileManager.default.createFile(atPath: disk.path, contents: nil) else {
            fail("could not create the private guest disk")
        }
        let diskHandle = try FileHandle(forWritingTo: disk)
        try diskHandle.truncate(atOffset: diskSize)
        try diskHandle.close()

        _ = try VZEFIVariableStore(creatingVariableStoreAt: efi)
        let identifier = VZGenericMachineIdentifier()
        try identifier.dataRepresentation.write(to: identity, options: [.atomic])

        for url in [disk, efi, identity] {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        FileHandle.standardOutput.write(Data("Visual VM native state initialization passed. No VM was created or started.\n".utf8))
    }
}

do {
    try VisualVMStateInitializer.run()
} catch {
    VisualVMStateInitializer.fail(error.localizedDescription)
}
