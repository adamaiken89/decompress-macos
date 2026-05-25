// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Decompress",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Decompress",
            path: "Sources/Decompress",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DecompressTests",
            dependencies: ["Decompress"],
            path: "Tests/DecompressTests"
        ),
    ]
)
