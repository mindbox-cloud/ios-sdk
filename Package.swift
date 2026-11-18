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
                "MindboxLogger",
                "MindboxShared"
            ],
            path: "Mindbox",
            exclude: ["Info.plist", "Shared"],
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
            name: "MindboxLogger",
            path: "MindboxLogger"
        ),
        // Compiled straight into each module by CocoaPods and the Xcode project; SwiftPM needs it as a target.
        .target(
            name: "MindboxShared",
            path: "Mindbox/Shared"
        )
    ]
)
