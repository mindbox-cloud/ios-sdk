// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Mindbox",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Mindbox",
            targets: ["Mindbox"]),
        .library(
            name: "MindboxNotificationsService",
            targets: ["MindboxNotifications"]),
        .library(
            name: "MindboxNotificationsContent",
            targets: ["MindboxNotifications"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Mindbox",
            dependencies: [
                "SDKVersionProvider",
                "MindboxShared",
                "MindboxLogger"
            ],
            path: "Mindbox",
            exclude: ["Info.plist"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "MindboxNotifications",
            dependencies: ["SDKVersionProvider", "MindboxShared"],
            path: "MindboxNotifications",
            exclude:  ["Info.plist"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "SDKVersionProvider",
            path: "SDKVersionProvider"
        ),
        .target(
            name: "MindboxShared",
            path: "MindboxShared"
        ),
        .target(
            name: "MindboxLogger",
            path: "MindboxLogger"
        )
    ]
)
