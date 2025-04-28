// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Mindbox",
    platforms: [.iOS(.v12)],
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
            dependencies: ["SDKVersionProvider", "MindboxLogger"],
            path: "Mindbox",
            exclude: ["Info.plist"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "MindboxNotifications",
            dependencies: ["SDKVersionProvider", "MindboxLogger"],
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
            path: "MindboxLogger",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .binaryTarget(
            name: "AbMixer",
            url: "https://github.com/mindbox-cloud/kmp-abmixer/releases/download/1.0.0/AbMixer.xcframework.zip",
            checksum: "5c8d4ad71fdd52043e5b45ceb0e2666c66b2095f8aa563bd2af9b62ca0d66436"
        ),
    ]
)
