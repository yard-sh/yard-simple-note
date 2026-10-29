// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SimpleNote",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "SimpleNote",
            path: "Sources/SimpleNote"
        ),
        .testTarget(
            name: "SimpleNoteTests",
            dependencies: ["SimpleNote"],
            path: "Tests/SimpleNoteTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
