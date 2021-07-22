// This file contains the fastlane.tools configuration
// You can find the documentation at https://docs.fastlane.tools
//
// For a list of all available actions, check out
//
//     https://docs.fastlane.tools/actions
//

import Foundation

class Fastfile: LaneFile {
    private let workspace = "Mindbox.xcworkspace"

    func buildLane() {
        desc("Build for testing")
        scan(workspace: workspace,
             derivedDataPath: "derivedData",
             buildForTesting: true,
             xcargs: "CI=true"
        )
    }

    func unitTestLane() {
        desc("Run unit tests")
        scan(workspace: workspace,
             onlyTesting: ["MindboxTests", "MindboxNotificationsTests"],
             clean: true,
             testWithoutBuilding: false,
             xcargs: "CI=true"
        )
    }
}
