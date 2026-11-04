// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TiempoPomo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TiempoPomo",
            path: "Sources/TiempoPomo"
        ),
        .testTarget(
            name: "TiempoPomoTests",
            dependencies: ["TiempoPomo"],
            path: "Tests/TiempoPomoTests"
        ),
    ]
)
