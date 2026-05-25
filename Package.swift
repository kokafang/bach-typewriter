// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "bach-typewriter-swift",
    platforms: [
        .macOS(.v10_15)
    ],
    targets: [
        .executableTarget(
            name: "bach-typewriter-swift",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "BachAudioHelper"
        ),
    ]
)
