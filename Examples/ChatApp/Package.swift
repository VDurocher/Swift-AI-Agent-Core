// swift-tools-version: 6.0
// Package de démonstration SwiftUI pour le portfolio — macOS 14+ uniquement

import PackageDescription

let package = Package(
    name: "ChatApp",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Dépendance locale vers la library Swift-AI-Agent-Core
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "ChatApp",
            dependencies: [
                .product(name: "SwiftAIAgentCore", package: "Swift-AI-Agent-Core")
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        )
    ],
    swiftLanguageVersions: [.v6]
)
