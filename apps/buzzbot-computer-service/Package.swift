// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuzzBotComputerService",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "buzzbot-computer-service", targets: ["BuzzBotComputerService"]),
        .executable(name: "buzzbot-guest-helper", targets: ["BuzzBotGuestHelper"]),
    ],
    targets: [
        .target(
            name: "BuzzBotProtocol",
            path: "Sources/BuzzBotProtocol"
        ),
        .executableTarget(
            name: "BuzzBotComputerService",
            dependencies: ["BuzzBotProtocol"],
            path: "Sources/BuzzBotComputerService",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Virtualization"),
                .linkedFramework("Network"),
            ]
        ),
        .executableTarget(
            name: "BuzzBotGuestHelper",
            dependencies: ["BuzzBotProtocol"],
            path: "Sources/BuzzBotGuestHelper",
            exclude: ["com.opndrm.buzzbot-guest-helper.plist", "install-guest-helper.sh"],
            sources: ["BuzzBotGuestHelper.swift"]
        ),
        .testTarget(
            name: "BuzzBotComputerServiceTests",
            dependencies: ["BuzzBotProtocol", "BuzzBotComputerService"],
            path: "Tests/BuzzBotComputerServiceTests"
        ),
    ]
)
