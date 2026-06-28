// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Upright",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Upright",
            path: "Sources/PostureCorrector",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
