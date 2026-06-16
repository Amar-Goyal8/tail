// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tail",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Tail",
            path: "Sources/Tail"
        )
    ]
)
