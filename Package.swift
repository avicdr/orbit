// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "OrbitShared", targets: ["OrbitShared"])
    ],
    targets: [
        .target(
            name: "OrbitShared",
            path: "Orbit/Shared"
        ),
        .testTarget(
            name: "OrbitSharedTests",
            dependencies: ["OrbitShared"],
            path: "Tests/OrbitSharedTests"
        )
    ]
)
