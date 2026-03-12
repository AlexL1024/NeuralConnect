// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MemosKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "MemosKit", targets: ["MemosKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AlexL1024/EverMemOSKit.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "MemosKit",
            dependencies: [
                .product(name: "EverMemOSKit", package: "EverMemOSKit"),
            ],
            path: "Sources/MemosKit"
        ),
        .testTarget(
            name: "MemosKitTests",
            dependencies: ["MemosKit"],
            path: "Tests/MemosKitTests"
        ),
    ]
)

