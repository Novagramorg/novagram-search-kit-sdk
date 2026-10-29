// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "NovagramSearchKit",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v13)
    ],
    products: [
        .library(name: "NovagramSearchKit", targets: ["NovagramSearchKit"])
    ],
    targets: [
        .target(
            name: "NovagramSearchKit",
            path: "Sources/NovagramSearchKit"
        ),
        .testTarget(
            name: "NovagramSearchKitTests",
            dependencies: ["NovagramSearchKit"],
            path: "Tests/NovagramSearchKitTests"
        )
    ]
)
