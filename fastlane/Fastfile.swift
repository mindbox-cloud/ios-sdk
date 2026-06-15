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
             testplan: "Mindbox",
             clean: true,
             outputDirectory: "test_output",
             outputTypes: "junit",
             xcodebuildFormatter: "xcbeautify",
             resultBundle: .userDefined(true),
             disableConcurrentTesting: true,
             testWithoutBuilding: .userDefined(false),
             xcargs: "CI=true"
        )
    }

    // MARK: - Sanitizer lanes (nightly scaffolding — intentionally NOT wired into CI yet)
    // Each runs the full unit-test set under a dedicated sanitizer test plan.
    // They are expected to stay red until the data races ThreadSanitizer surfaced
    // are fixed, so keep them off the PR/develop pipeline and run on a schedule.

    func threadSanitizerLane() {
        desc("Run tests under ThreadSanitizer (nightly; not wired to CI yet)")
        scan(project: .userDefined(project),
             scheme: "Mindbox",
             prelaunchSimulator: .userDefined(true),
             testplan: "ThreadSanitizer",
             clean: true,
             outputDirectory: "test_output_tsan",
             outputTypes: "junit",
             xcodebuildFormatter: "xcbeautify",
             resultBundle: .userDefined(true),
             disableConcurrentTesting: true,
             testWithoutBuilding: .userDefined(false),
             xcargs: "CI=true"
        )
    }

    func addressSanitizerLane() {
        desc("Run tests under AddressSanitizer (nightly; not wired to CI yet)")
        scan(project: .userDefined(project),
             scheme: "Mindbox",
             prelaunchSimulator: .userDefined(true),
             testplan: "AddressSanitizer",
             clean: true,
             outputDirectory: "test_output_asan",
             outputTypes: "junit",
             xcodebuildFormatter: "xcbeautify",
             resultBundle: .userDefined(true),
             disableConcurrentTesting: true,
             testWithoutBuilding: .userDefined(false),
             xcargs: "CI=true"
        )
    }
}
