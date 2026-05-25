// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Decompress",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Decompress",
            path: "Sources/Decompress"
        ),
        .testTarget(
            name: "DecompressTests",
            dependencies: ["Decompress"],
            path: "Tests/DecompressTests"
        ),
    ]
)
