// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InfomaniakNotifications",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "InfomaniakNotifications",
            targets: ["InfomaniakNotifications"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Infomaniak/ios-core", .upToNextMajor(from: "15.0.0")),
    ],
    targets: [
        .target(
            name: "InfomaniakNotifications",
            dependencies: [
                .product(name: "InfomaniakCore", package: "ios-core"),
            ]),
        .testTarget(
            name: "InfomaniakNotificationsTests",
            dependencies: ["InfomaniakNotifications"]),
    ])
