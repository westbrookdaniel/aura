// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aura",
    platforms: [
        .macOS("13.3")
    ],
    products: [
        .executable(
            name: "Aura",
            targets: ["Aura"]
        )
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "WhisperFramework",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.5/whisper-v1.7.5-xcframework.zip",
            checksum: "c7faeb328620d6012e130f3d705c51a6ea6c995605f2df50f6e1ad68c59c6c4a"
        ),
        .executableTarget(
            name: "Aura",
            dependencies: [
                "WhisperFramework"
            ],
            path: "Sources/Aura",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "AuraTests",
            dependencies: ["Aura"],
            path: "Tests/AuraTests"
        )
    ]
)
