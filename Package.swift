// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotificationManager",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),   
            .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NotificationManager",
            targets: ["NotificationManager"]),
    ],
    targets: [
        .target(
            name: "NotificationManager"),
        .testTarget(
            name: "NotificationManagerTests",
            dependencies: ["NotificationManager"]),
    ]
)
