// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleNote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SimpleNote",
            path: "Sources/SimpleNote",
            resources: [
                .copy("Resources/Fonts")
            ]
        )
    ]
)
