// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OPNDRMVM",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "opndrm-vm", targets: ["OPNDRMVM"]),
        .executable(name: "opndrm-guest-helper", targets: ["OPNDRMGuestHelper"]),
    ],
    targets: [
        .target(
            name: "OPNDRMProtocol",
            path: "Sources/OPNDRMProtocol"
        ),
        .executableTarget(
            name: "OPNDRMVM",
            dependencies: ["OPNDRMProtocol"],
            path: "Sources/OPNDRMVM",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Virtualization"),
                .linkedFramework("Network"),
            ]
        ),
        .target(
            name: "OPNDRMGuestEngine",
            dependencies: ["OPNDRMProtocol"],
            path: "Sources/OPNDRMGuestEngine"
        ),
        .executableTarget(
            name: "OPNDRMGuestHelper",
            dependencies: ["OPNDRMGuestEngine", "OPNDRMProtocol"],
            path: "Sources/OPNDRMGuestHelper",
            exclude: ["com.opndrm.guest-helper.plist", "install-guest-helper.sh"],
            sources: ["OPNDRMGuestHelper.swift"],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(
            name: "OPNDRMVMTests",
            dependencies: ["OPNDRMGuestEngine", "OPNDRMProtocol", "OPNDRMVM"],
            path: "Tests/OPNDRMVMTests"
        ),
    ]
)
