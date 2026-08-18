// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuzzContainerWindow",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "buzz-container-window", targets: ["BuzzContainerWindow"]),
    ],
    targets: [
        .executableTarget(
            name: "BuzzContainerWindow",
            path: "Sources/BuzzContainerWindow"
        ),
        .testTarget(
            name: "BuzzContainerWindowTests",
            dependencies: ["BuzzContainerWindow"],
            path: "Tests/BuzzContainerWindowTests"
        ),
    ]
)
