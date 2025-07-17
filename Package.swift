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
        .binaryTarget(
            name: "MindboxCommon",
            url: "https://github.com/mindbox-cloud/kmp-common-sdk/releases/download/1.0.1-SNAPSHOT/MindboxCommon.xcframework.zip",
            checksum: "39e7959a637e0797674c2188c81fcafc10dd7c6bf79f097365779bcec0316d62"
        ),
        .target(
            name: "Mindbox",
            dependencies: ["SDKVersionProvider", "MindboxLogger", "MindboxCommon"],
            path: "Mindbox",
            exclude: ["Info.plist"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "MindboxNotifications",
            dependencies: ["SDKVersionProvider", "MindboxLogger", "MindboxCommon"],
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
        )
    ]
)
