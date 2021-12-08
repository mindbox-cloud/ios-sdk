// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Mindbox",
    platforms: [.iOS(.v10)],
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
            path: "Mindbox",
            exclude: ["Info.plist"]),
        .target(
            name: "MindboxNotifications",
            dependencies: [],
            path: "MindboxNotifications",
            exclude:  ["Info.plist"])
    ]
)
