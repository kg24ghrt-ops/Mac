// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HandwritingSimulator",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HandwritingSimulator",
            path: "Sources/HandwritingSimulator"
        )
    ]
)