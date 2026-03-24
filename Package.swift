// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aura",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Aura",
            targets: ["Aura"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Aura",
            path: "Sources/Aura"
        ),
        .testTarget(
            name: "AuraTests",
            dependencies: ["Aura"],
            path: "Tests/AuraTests"
        )
    ]
)
