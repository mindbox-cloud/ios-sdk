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
    }

    func unitTestLane() {
        desc("Run unit tests")
        scan(project: .userDefined(project),
             scheme: "Mindbox",
             prelaunchSimulator: .userDefined(true),
             onlyTesting: ["MindboxTests"],
             clean: true,
             xcodebuildFormatter: "xcbeautify",
             disableConcurrentTesting: true,
             testWithoutBuilding: .userDefined(false),
             xcargs: "CI=true"
        )
    }
}
