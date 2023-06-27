import Foundation

class Fastfile: LaneFile {
    private let project = "Mindbox.xcodeproj"

    func buildLane() {
        desc("Build for testing")
        scan(
            project: .userDefined(project),
            scheme: "Mindbox",
            xcodebuildFormatter: "",
            derivedDataPath: "derivedData",
            buildForTesting: .userDefined(true),
            xcargs: "CI=true"
        )
        scan(
            project: .userDefined(project),
            scheme: "MindboxNotifications",
            xcodebuildFormatter: "",
            derivedDataPath: "derivedData",
            buildForTesting: .userDefined(true),
            xcargs: "CI=true"
        )
    }

    func unitTestLane() {
        desc("Run unit tests")
        let deviceName = ProcessInfo.processInfo.environment["DEVICE_NAME"] ?? "iPhone 12"
        let destination = "platform=iOS Simulator,name=\(deviceName)"

        scan(project: .userDefined(project),
             scheme: "Mindbox",
             onlyTesting: ["MindboxTests"],
             clean: true,
             xcodebuildFormatter: "",
             disableConcurrentTesting: true,
             testWithoutBuilding: .userDefined(false),
             xcargs: "CI=true -destination '\(destination)'"
        )
        scan(
            project: .userDefined(project),
            scheme: "MindboxNotifications",
            onlyTesting: ["MindboxNotificationsTests"],
            clean: true,
            xcodebuildFormatter: "",
            testWithoutBuilding: .userDefined(false),
            xcargs: "CI=true -destination '\(destination)'"
        )
    }
}
