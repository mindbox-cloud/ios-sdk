// This file contains the fastlane.tools configuration
// You can find the documentation at https://docs.fastlane.tools
//
// For a list of all available actions, check out
//
//     https://docs.fastlane.tools/actions
//

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
        scan(project: .userDefined(project),
             scheme: "Mindbox",
             onlyTesting: ["MindboxTests"],
             clean: true,
             xcodebuildFormatter: "",
             disableConcurrentTesting: true,
             testWithoutBuilding: .userDefined(false),
             xcargs: "CI=true"
        )
        scan(
            project: .userDefined(project),
            scheme: "MindboxNotifications",
            onlyTesting: ["MindboxNotificationsTests"],
            clean: true,
            xcodebuildFormatter: "",
            testWithoutBuilding: .userDefined(false),
            xcargs: "CI=true"
        )
    }
}
