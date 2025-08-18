// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ticklings",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Ticklings", targets: ["TicklingsApp"])
    ],
    targets: [
        .executableTarget(
            name: "TicklingsApp",
            dependencies: [],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
