// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RoverApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RoverApp",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
