// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoggingKit",
    platforms: [
        .iOS(.v14), .macOS(.v11), .tvOS(.v14), .watchOS(.v7)
    ],
    products: [
        .library(name: "LoggingKit", targets: ["LoggingKit"])
    ],
    targets: [
        .target(
            name: "LoggingKit",
            path: "Sources/LoggingKit",
            swiftSettings: [
                .define("LOGGINGKIT_USE_FILEID")
            ]
        ),
        .testTarget(
            name: "LoggingKitTests",
            dependencies: ["LoggingKit"],
            path: "Tests/LoggingKitTests"
        )
    ]
)
