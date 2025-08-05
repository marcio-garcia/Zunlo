// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AdStack",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AdStack",
            targets: ["AdStack"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", .upToNextMajor(from: "12.8.0"))
    ],
    targets: [
        .target(
            name: "AdStack",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ],
            path: "Sources/AdStack",
            resources: []
//            swiftSettings: [
//                .enableExperimentalFeature("StrictConcurrency") // optional
//            ]
        ),
        .testTarget(
            name: "AdStackTests",
            dependencies: ["AdStack"],
            path: "Tests/AdStackTests"
        )
    ]
)
