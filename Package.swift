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
        .package(
            url: "https://github.com/mindbox-cloud/kmp-common-sdk-spm.git", 
            .exact("1.0.4")
        ) 
    ],
    targets: [
        .target(
            name: "Mindbox",
            dependencies: [
                "SDKVersionProvider",
                "MindboxLogger",
                .product(name: "MindboxCommon", package: "kmp-common-sdk-spm")
            ],
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
