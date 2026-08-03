// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HowManyTokens",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HowManyTokens",
            path: "Sources/HowManyTokens"
        )
    ]
)
