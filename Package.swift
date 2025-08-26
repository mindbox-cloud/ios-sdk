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
            url: "https://github.com/mindbox-cloud/kmp-common-sdk/releases/download/1.0.3-rc/MindboxCommon.xcframework.zip",
            checksum: "422dad4454addc735ea7469286dea5a828ee114c392b008af69188952ea004f4"
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
            dependencies: ["SDKVersionProvider"],
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
