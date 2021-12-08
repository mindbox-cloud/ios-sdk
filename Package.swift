// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Mindbox",
    products: [
        .library(
            name: "Mindbox",
            targets: ["Mindbox"]),
        .library(
            name: "MindboxNotifications",
            targets: ["MindboxNotifications"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Mindbox",
            dependencies: [],
            path: "Mindbox"),
        .testTarget(
            name: "MindboxNotifications",
            dependencies: [],
            path: "MindboxNotifications"),
    ]
)
