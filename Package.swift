// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TodoMenu",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TodoMenu",
            path: "Sources/TodoMenu"
        )
    ]
)
