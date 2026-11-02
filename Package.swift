// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PomTiempo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PomTiempo",
            path: "Sources/PomTiempo"
        )
    ]
)
