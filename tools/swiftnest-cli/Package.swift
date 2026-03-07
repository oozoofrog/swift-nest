// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftNestCLI",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "swiftnest", targets: ["SwiftNestCLI"]),
    ],
    targets: [
        .executableTarget(
            name: "SwiftNestCLI",
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftNestCLITests",
            dependencies: ["SwiftNestCLI"],
            path: "Tests"
        ),
    ]
)
