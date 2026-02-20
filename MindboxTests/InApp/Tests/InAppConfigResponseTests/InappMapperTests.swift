//
//  InappRemainingTargetingTests.swift
//  MindboxTests
//
//  Created by vailence on 14.11.2024.
//  Updated to Swift Testing by Serge & ChatGPT
//

import Testing
import Foundation
@testable import Mindbox

fileprivate enum InappTargetingConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case oneTargeting                  = "1-Targeting"
    case threeFourFiveRequests         = "3-4-5-TargetingRequests"
    case sevenRequests                 = "7-TargetingRequests"
    case eightRequests                 = "8-TargetingRequests"
    case nineRequests                  = "9-TargetingRequests"
    case fourteenRequests              = "14-TargetingRequests"
    case fifteenTargeting              = "15-Targeting"
    case sixteenSeventeenRequests      = "16-17-TargetingRequests"
    case twentySevenRequests           = "27-TargetingRequests"
    case thirtyOneRequests             = "31-TargetingRequests"
    case fortyFourTargeting            = "44-Targeting"
    case fortyFiveTargeting            = "45-Targeting"
    case fortySixTargeting             = "46-Targeting"
}

// MARK: - Suite

@Suite("In-app remaining targeting tests")
struct InappRemainingTargetingTests {

    private var targetingChecker: InAppTargetingCheckerProtocol
    private var mockDataFacade: MockInAppConfigurationDataFacade
    private var mapper: InappMapperProtocol
    private var persistenceStorage: PersistenceStorage

    init() {
        // Common test DI configuration
        TestConfiguration.configure()

        // Clear temporary in-app state
        SessionTemporaryStorage.shared.erase()

        self.targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)

        let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try? databaseRepository.erase()

        // We require the mock facade here. If DI is misconfigured, fail fast.
        let facade = DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self)
        guard let mock = facade as? MockInAppConfigurationDataFacade else {
            fatalError("Expected MockInAppConfigurationDataFacade from DI. Check test DI configuration.")
        }
        self.mockDataFacade = mock
        self.mockDataFacade.cleanTargetingArray()
        self.mockDataFacade.cleanImageDownloadFailures()

        self.mapper = DI.injectOrFail(InappMapperProtocol.self)
        self.persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        self.persistenceStorage.shownDatesByInApp = [:]
    }

    // MARK: - Helpers

    /// Wrapper around `mapper.handleInapps` that exposes async/await
    /// instead of using XCTestExpectation-based callbacks.
    @discardableResult
    private func handleInapps(
        event: ApplicationEvent?,
        config: ConfigResponse
    ) async -> InAppFormData? {
        await withCheckedContinuation { continuation in
            mapper.handleInapps(event, config) { formData in
                continuation.resume(returning: formData)
            }
        }
    }

    /// Asserts that the given in-app ID is present in `showArray`
    /// and therefore is expected to be shown.
    private func assertTargetingShows(id: String) {
        #expect(
            mockDataFacade.showArray.contains(id),
            "ID \(id) is expected to be shown"
        )
    }

    /// Asserts that the collected targeting IDs match the expected set,
    /// ignoring ordering.
    private func assertTargetingEquals(ids: [String]) {
        #expect(
            Set(mockDataFacade.targetingArray) == Set(ids),
            "Targeting array does not match the expected IDs. Expected: \(ids), actual: \(mockDataFacade.targetingArray)"
        )
    }

    /// Small helper to wait until the async logic populates `targetingArray`.
    /// Preferable to hard-coded `DispatchQueue.main.asyncAfter` in XCTest-style tests.
    private func waitForTargetingArray(
        expectedCount: Int,
        timeout: TimeInterval = 5
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if mockDataFacade.targetingArray.count >= expectedCount {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        }

        Issue.record("Timed out waiting for targetingArray to reach count \(expectedCount). Current: \(mockDataFacade.targetingArray)")
    }

    // MARK: - Tests

    @Test("True in-app, not shown before → should be shown", .tags(.remainingTargeting))
    func inappTrue_notShownBefore() async throws {
        let config = try InappTargetingConfig.oneTargeting.getConfig()
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1"])
    }

    @Test("Two true in-apps, none shown before", .tags(.remainingTargeting))
    func twoInappsTrue_notShownBefore() async throws {
        let config = try InappTargetingConfig.threeFourFiveRequests.getConfig()
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1", "2"])
    }

    @Test("Two true in-apps, first already shown", .tags(.remainingTargeting))
    func twoInappsTrue_firstShownBefore() async throws {
        let config = try InappTargetingConfig.threeFourFiveRequests.getConfig()
        persistenceStorage.shownDatesByInApp = ["1": [Date()]]

        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "2")
        assertTargetingEquals(ids: ["2", "1"])
    }

    @Test("Two true in-apps, both already shown", .tags(.remainingTargeting))
    func twoInappsTrue_bothAlreadyShown() async throws {
        let config = try InappTargetingConfig.threeFourFiveRequests.getConfig()
        persistenceStorage.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]

        await handleInapps(event: nil, config: config)

        #expect(!SessionTemporaryStorage.shared.isPresentingInAppMessage)
        assertTargetingEquals(ids: ["1", "2"])
    }
    
    @Test("Image download error adds in-app show failure", .tags(.remainingTargeting))
    func imageDownloadError_addsFailure() async throws {
        let config = try InappTargetingConfig.oneTargeting.getConfig()
        let imageError = MindboxError.serverError(
            .init(
                status: .internalServerError,
                errorMessage: "image download failed",
                httpStatusCode: 500
            )
        )
        mockDataFacade.downloadImageError = imageError
        mockDataFacade.cleanImageDownloadFailures()
        
        _ = await handleInapps(event: nil, config: config)
        
        #expect(mockDataFacade.imageDownloadFailures.count == 1)
        #expect(mockDataFacade.imageDownloadFailures.first?.inappId == "1")
        #expect(mockDataFacade.imageDownloadFailures.first?.details == imageError.localizedDescription)
    }
    
    @Test("Image download non-5xx error does not add in-app show failure", .tags(.remainingTargeting))
    func imageDownloadNon5xxError_doesNotAddFailure() async throws {
        let config = try InappTargetingConfig.oneTargeting.getConfig()
        let imageError = MindboxError.protocolError(
            .init(
                status: .protocolError,
                errorMessage: "not found",
                httpStatusCode: 404
            )
        )
        mockDataFacade.downloadImageError = imageError
        mockDataFacade.cleanImageDownloadFailures()
        
        _ = await handleInapps(event: nil, config: config)
        
        #expect(mockDataFacade.imageDownloadFailures.isEmpty)
    }

    @Test("Single geo in-app, not shown before", .tags(.remainingTargeting, .geoTargeting))
    func oneInappGeo_notShownBefore() async throws {
        let config = try InappTargetingConfig.sevenRequests.getConfig()
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1"])
    }

    @Test("One true + one geo in-app, none shown before", .tags(.remainingTargeting, .geoTargeting))
    func oneTrue_oneGeo_notShownBefore() async throws {
        let config = try InappTargetingConfig.eightRequests.getConfig()
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1", "2"])
    }

    @Test("True shown, operation and geo+segment in-app", .tags(.remainingTargeting, .geoTargeting))
    func trueShown_operationTest_trueNotShown_geo_segment() async throws {
        let config = try InappTargetingConfig.nineRequests.getConfig()

        persistenceStorage.shownDatesByInApp = ["1": [Date()]]
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        targetingChecker.checkedSegmentations = [
            .init(segmentation: .init(ids: .init(externalId: "0000000")), segment: nil)
        ]
        SessionTemporaryStorage.shared.segmentationRequestResult = .success(targetingChecker.checkedSegmentations)

        // First pass (no event)
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "3")
        assertTargetingEquals(ids: ["3", "1", "4", "5"])

        mockDataFacade.cleanTargetingArray()

        // Second pass (with event)
        let event = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: event, config: config)
        assertTargetingEquals(ids: ["2"])
    }

    @Test("One in-app for operation 1 OR 2", .tags(.remainingTargeting))
    func oneInapp_twoOperations1Or2() async throws {
        let config = try InappTargetingConfig.fourteenRequests.getConfig()

        // Operation "1"
        let event1 = ApplicationEvent(name: "1", model: nil)
        await handleInapps(event: event1, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1"])

        mockDataFacade.cleanTargetingArray()

        // Operation "2"
        let event2 = ApplicationEvent(name: "2", model: nil)
        await handleInapps(event: event2, config: config)
        assertTargetingEquals(ids: ["1"])
    }

    @Test("One in-app for operation and segment", .tags(.remainingTargeting))
    func oneInapp_forOperationAndSegment() async throws {
        let config = try InappTargetingConfig.fifteenTargeting.getConfig()

        targetingChecker.checkedSegmentations = [
            .init(segmentation: .init(ids: .init(externalId: "0000000")), segment: nil)
        ]
        SessionTemporaryStorage.shared.segmentationRequestResult = .success(targetingChecker.checkedSegmentations)

        // No event
        await handleInapps(event: nil, config: config)
        assertTargetingEquals(ids: [])

        mockDataFacade.cleanTargetingArray()

        // With event "test"
        let event = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: event, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1"])
    }

    @Test("True + operation test", .tags(.remainingTargeting))
    func true_operationTest() async throws {
        let config = try InappTargetingConfig.sixteenSeventeenRequests.getConfig()

        // First, true-targeting in-app
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1"])

        mockDataFacade.cleanTargetingArray()

        // First "test" event
        let testEvent = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEvent, config: config)
        assertTargetingEquals(ids: ["2"])

        mockDataFacade.cleanTargetingArray()

        // Second "test" event
        let testAgain = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testAgain, config: config)
        assertTargetingEquals(ids: ["2"])
    }

    @Test("Unknown in-app + lower SDK + true in-app", .tags(.remainingTargeting))
    func unknownInapp_lowerSDK_trueInapp() async throws {
        let config = try InappTargetingConfig.twentySevenRequests.getConfig()
        await handleInapps(event: nil, config: config)
        assertTargetingEquals(ids: ["3"])
    }

    // MARK: - A/B tests (31-TargetingRequests)

    @Test("Four in-apps with A/B tests, device variant 1", .tags(.remainingTargeting, .abTesting))
    func fourInappsWithABTests_variant1() async throws {
        let config = try InappTargetingConfig.thirtyOneRequests.getConfig()
        persistenceStorage.deviceUUID = "40909d27-4bef-4a8d-9164-6bfcf58ecc76" // variant 1
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        // Initial request
        await handleInapps(event: nil, config: config)

        // We wait until the facade accumulates targetings (previously there was asyncAfter + expectation here)
        await waitForTargetingArray(expectedCount: 3)
        assertTargetingEquals(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        // Event "test" → A/B-result
        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEventAgain, config: config)
        assertTargetingEquals(ids: ["4"])
    }

    @Test("Four in-apps with A/B tests, device variant 2", .tags(.remainingTargeting, .abTesting))
    func fourInappsWithABTests_variant2() async throws {
        let config = try InappTargetingConfig.thirtyOneRequests.getConfig()
        persistenceStorage.deviceUUID = "b4e0f767-fe8f-4825-9772-f1162f2db52d" // variant 2
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        await handleInapps(event: nil, config: config)
        await waitForTargetingArray(expectedCount: 3)
        assertTargetingEquals(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEventAgain, config: config)
        assertTargetingEquals(ids: ["4"])
    }

    @Test("Four in-apps with A/B tests, device variant 3", .tags(.remainingTargeting, .abTesting))
    func fourInappsWithABTests_variant3() async throws {
        let config = try InappTargetingConfig.thirtyOneRequests.getConfig()
        persistenceStorage.deviceUUID = "55fbd965-c658-47a8-8786-d72ba79b38a2" // variant 3
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        await handleInapps(event: nil, config: config)
        await waitForTargetingArray(expectedCount: 3)
        assertTargetingEquals(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEventAgain, config: config)
        assertTargetingEquals(ids: ["4"])
    }

    // MARK: - Geo + operations (44 / 45 / 46)

    @Test("geoFitOrTest + test + test2, initial geo", .tags(.remainingTargeting, .geoTargeting))
    func geoFitOrTest_operationTest_operationTest_operationTest2_geo() async throws {
        let config = try InappTargetingConfig.fortyFourTargeting.getConfig()
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        // Initial geo-based call
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1", "5"])

        mockDataFacade.cleanTargetingArray()

        // "test" event
        let testEvent = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEvent, config: config)
        assertTargetingEquals(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        // "test2" event
        let testEvent2 = ApplicationEvent(name: "test2", model: nil)
        await handleInapps(event: testEvent2, config: config)
        assertTargetingEquals(ids: ["4"])
    }

    @Test("geo + test + test2 + geoFitOrTest", .tags(.remainingTargeting, .geoTargeting))
    func geo_operationTest_operationTest_operationTest2_geoFitOrTest() async throws {
        let config = try InappTargetingConfig.fortyFiveTargeting.getConfig()
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        // Initial geo-based call
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1", "5"])

        mockDataFacade.cleanTargetingArray()

        // "test" event
        let testEvent = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEvent, config: config)
        assertTargetingEquals(ids: ["2", "3", "5"])

        mockDataFacade.cleanTargetingArray()

        // "test2" event
        let testEvent2 = ApplicationEvent(name: "test2", model: nil)
        await handleInapps(event: testEvent2, config: config)
        assertTargetingEquals(ids: ["4"])
    }

    @Test("geoFitOrTest + test + test2 + geoFitOrTest", .tags(.remainingTargeting, .geoTargeting))
    func geoFitOrTest_operationTest_operationTest_operationTest2_geoFitOrTest() async throws {
        let config = try InappTargetingConfig.fortySixTargeting.getConfig()
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestResult = .success(targetingChecker.geoModels)

        // Initial geo-based call
        await handleInapps(event: nil, config: config)
        assertTargetingShows(id: "1")
        assertTargetingEquals(ids: ["1", "5"])

        mockDataFacade.cleanTargetingArray()

        // "test" event
        let testEvent = ApplicationEvent(name: "test", model: nil)
        await handleInapps(event: testEvent, config: config)
        assertTargetingEquals(ids: ["1", "2", "3", "5"])

        mockDataFacade.cleanTargetingArray()

        // "test2" event
        let testEvent2 = ApplicationEvent(name: "test2", model: nil)
        await handleInapps(event: testEvent2, config: config)
        assertTargetingEquals(ids: ["4"])
    }
}
