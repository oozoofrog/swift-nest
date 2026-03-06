// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HarnessCLI",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "harness", targets: ["HarnessCLI"]),
    ],
    targets: [
        .executableTarget(
            name: "HarnessCLI",
            path: "Sources"
        ),
    ]
)
