// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tail",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Tail",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Sources/Tail"
        )
    ]
)
