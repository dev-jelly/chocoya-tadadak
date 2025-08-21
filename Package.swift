// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tadadak",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Tadadak", targets: ["TadadakApp"])
    ],
    targets: [
        .executableTarget(
            name: "TadadakApp",
            dependencies: [],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
