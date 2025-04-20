// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PostlogAnalytics",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PostlogAnalytics",
            targets: ["PostlogAnalytics"]),
    ],
    targets: [
        .target(
            name: "PostlogAnalytics",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "PostlogAnalyticsTests",
            dependencies: ["PostlogAnalytics"],
            path: "Tests"),
    ]
)
