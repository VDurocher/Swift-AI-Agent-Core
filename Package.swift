// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftAIAgentCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftAIAgentCore",
            targets: ["SwiftAIAgentCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftAIAgentCore",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftAIAgentCoreTests",
            dependencies: ["SwiftAIAgentCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
