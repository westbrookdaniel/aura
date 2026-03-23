// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Listener",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Listener",
            targets: ["Listener"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Listener",
            path: "Sources/Listener"
        ),
        .testTarget(
            name: "ListenerTests",
            dependencies: ["Listener"],
            path: "Tests/ListenerTests"
        )
    ]
)
