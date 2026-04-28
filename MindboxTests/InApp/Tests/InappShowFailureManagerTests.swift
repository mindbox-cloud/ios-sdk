//
//  InappShowFailureManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.02.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import XCTest
import UIKit
@testable import Mindbox

final class InappShowFailureManagerTests: XCTestCase {
    private var databaseRepository: InappShowFailureDatabaseRepositoryMock!
    private var featureToggleManager: FeatureToggleManager!
    private var manager: InappShowFailureManager!

    override func setUp() {
        super.setUp()
        databaseRepository = InappShowFailureDatabaseRepositoryMock()
        featureToggleManager = FeatureToggleManager()
        manager = InappShowFailureManager(
            databaseRepository: databaseRepository,
            featureToggleManager: featureToggleManager
        )
    }

    override func tearDown() {
        manager = nil
        featureToggleManager = nil
        databaseRepository = nil
        super.tearDown()
    }

    func testAddFailureAndSend_createsEventWithFailure() throws {
        manager.addFailure(
            inappId: "inapp-1",
            reason: .presentationFailed,
            details: "No window available"
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        XCTAssertEqual(event.type, .inAppShowFailureEvent)

        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].inappId, "inapp-1")
        XCTAssertEqual(failures[0].failureReason, .presentationFailed)
        XCTAssertEqual(failures[0].errorDetails, "No window available")
    }

    func testAddFailure_setsDateTimeUtcInsideMethod() throws {
        manager.addFailure(
            inappId: "inapp-2",
            reason: .unknownError,
            details: nil
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertFalse(failure.dateTimeUtc.isEmpty)
        XCTAssertNotNil(makeUTCFormatter().date(from: failure.dateTimeUtc))
    }

    func testAddFailure_duplicateInappId_isIgnored() throws {
        manager.addFailure(
            inappId: "inapp-duplicate",
            reason: .imageDownloadFailed,
            details: "first"
        )
        manager.addFailure(
            inappId: "inapp-duplicate",
            reason: .unknownError,
            details: "second"
        )

        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .imageDownloadFailed)
        XCTAssertEqual(failures[0].errorDetails, "first")
    }

    func testAddFailure_targetingFailure_priorityReplacesExisting() throws {
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .productSegmentRequestFailed,
            details: "product"
        )
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .geoRequestFailed,
            details: "geo"
        )
        manager.addFailure(
            inappId: "inapp-priority",
            reason: .customerSegmentRequestFailed,
            details: "segment"
        )

        manager.sendFailures()
        assertCreatedEventsCountEventually(1)

        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failures[0].errorDetails, "segment")
    }

    func testAddFailure_targetingFailure_priorityDoesNotDowngrade() throws {
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .customerSegmentRequestFailed,
            details: "segment"
        )
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .geoRequestFailed,
            details: "geo"
        )
        manager.addFailure(
            inappId: "inapp-priority-no-downgrade",
            reason: .productSegmentRequestFailed,
            details: "product"
        )

        manager.sendFailures()
        assertCreatedEventsCountEventually(1)

        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failures = try XCTUnwrap(decodeFailures(from: event))
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures[0].failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failures[0].errorDetails, "segment")
    }

    func testClearFailures_removesBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-clear",
            reason: .presentationFailed,
            details: "clear me"
        )
        manager.clearFailures()
        manager.sendFailures()

        assertCreatedEventsCountEventually(0)
    }

    func testSendFailures_success_clearsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-send-success",
            reason: .presentationFailed,
            details: nil
        )

        manager.sendFailures()
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
    }

    func testSendFailures_createEventFails_keepsBufferedFailures() {
        manager.addFailure(
            inappId: "inapp-retry",
            reason: .unknownError,
            details: "will retry"
        )
        databaseRepository.createError = InappShowFailureRepositoryError.createFailed

        manager.sendFailures()
        assertCreatedEventsCountEventually(0)

        databaseRepository.createError = nil
        manager.sendFailures()
        assertCreatedEventsCountEventually(1)
    }
    
    func testAddFailure_whenFeatureDisabled_doesNotBufferFailure() {
        applyFeatureToggle(shouldSendInAppShowError: false)
        
        manager.addFailure(
            inappId: "inapp-add-disabled",
            reason: .presentationFailed,
            details: "should be ignored"
        )
        
        applyFeatureToggle(shouldSendInAppShowError: true)
        manager.sendFailures()

        assertCreatedEventsCountEventually(0)
    }
    
    func testAddFailure_errorDetailsBelowLimit_isNotTruncated() throws {
        let details = String(repeating: "a", count: InappShowFailureManager.errorDetailsLimit - 1)

        manager.addFailure(inappId: "inapp-below-limit", reason: .unknownError, details: details)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails?.count, InappShowFailureManager.errorDetailsLimit - 1)
        XCTAssertEqual(failure.errorDetails, details)
    }

    func testAddFailure_errorDetailsAtLimit_isNotTruncated() throws {
        let details = String(repeating: "b", count: InappShowFailureManager.errorDetailsLimit)

        manager.addFailure(inappId: "inapp-at-limit", reason: .unknownError, details: details)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails?.count, InappShowFailureManager.errorDetailsLimit)
        XCTAssertEqual(failure.errorDetails, details)
    }

    func testAddFailure_errorDetailsAboveLimit_isTruncatedToLimit() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        let details = String(repeating: "c", count: limit + 500)

        manager.addFailure(inappId: "inapp-above-limit", reason: .unknownError, details: details)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails?.count, limit)
        XCTAssertEqual(failure.errorDetails, String(details.prefix(limit)))
    }

    func testAddFailure_errorDetailsNil_remainsNil() throws {
        manager.addFailure(inappId: "inapp-nil-details", reason: .unknownError, details: nil)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertNil(failure.errorDetails)
    }

    func testAddFailure_errorDetailsEmpty_remainsEmpty() throws {
        manager.addFailure(inappId: "inapp-empty-details", reason: .unknownError, details: "")
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.errorDetails, "")
    }

    func testAddFailure_priorityReplacement_truncatesNewDetails() throws {
        let limit = InappShowFailureManager.errorDetailsLimit
        let longDetails = String(repeating: "d", count: limit + 200)

        manager.addFailure(inappId: "inapp-priority-truncate", reason: .productSegmentRequestFailed, details: "short")
        manager.addFailure(inappId: "inapp-priority-truncate", reason: .customerSegmentRequestFailed, details: longDetails)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.failureReason, .customerSegmentRequestFailed)
        XCTAssertEqual(failure.errorDetails?.count, limit)
        XCTAssertEqual(failure.errorDetails, String(longDetails.prefix(limit)))
    }

    func testSendFailures_whenFeatureDisabled_doesNotSendAndKeepsBufferedFailures() throws {
        manager.addFailure(
            inappId: "inapp-toggle-disabled",
            reason: .presentationFailed,
            details: "disabled"
        )
        applyFeatureToggle(shouldSendInAppShowError: false)

        manager.sendFailures()
        assertCreatedEventsCountEventually(0)

        applyFeatureToggle(shouldSendInAppShowError: true)
        manager.sendFailures()

        assertCreatedEventsCountEventually(1)
        let event = try XCTUnwrap(databaseRepository.createdEvents.first)
        let failure = try XCTUnwrap(decodeFailures(from: event)?.first)
        XCTAssertEqual(failure.inappId, "inapp-toggle-disabled")
    }
}

private extension InappShowFailureManagerTests {
    struct InAppShowFailuresBody: Decodable {
        let failures: [InAppShowFailure]
    }

    func decodeFailures(from event: Event) -> [InAppShowFailure]? {
        BodyDecoder<InAppShowFailuresBody>(decodable: event.body)?.body.failures
    }

    func makeUTCFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }
    
    func applyFeatureToggle(shouldSendInAppShowError: Bool) {
        let settingsJSON = """
        {
          "featureToggles": {
            "MobileSdkShouldSendInAppShowError": \(shouldSendInAppShowError ? "true" : "false")
          }
        }
        """
        let settingsData = settingsJSON.data(using: .utf8) ?? Data()
        let settings = try? JSONDecoder().decode(Settings.self, from: settingsData)
        featureToggleManager.applyFeatureToggles(settings?.featureToggles)
    }

    func assertCreatedEventsCountEventually(
        _ expectedCount: Int,
        timeout: TimeInterval = 1,
        settleTime: TimeInterval = 0.05,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = waitUntil(timeout: timeout) {
            databaseRepository.createdEvents.count == expectedCount
        }

        // Let pending async tasks finish and verify count is stable.
        RunLoop.current.run(until: Date().addingTimeInterval(settleTime))
        XCTAssertEqual(databaseRepository.createdEvents.count, expectedCount, file: file, line: line)
    }

    @discardableResult
    func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.01,
        condition: () -> Bool
    ) -> Bool {
        let timeoutDate = Date().addingTimeInterval(timeout)
        while Date() < timeoutDate {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }

        return condition()
    }
}

private enum InappShowFailureRepositoryError: Error {
    case createFailed
}

private final class InappShowFailureDatabaseRepositoryMock: DatabaseRepositoryProtocol {
    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?

    private let stateQueue = DispatchQueue(label: "com.Mindbox.InappShowFailureDatabaseRepositoryMock.state")
    private var _createError: Error?
    private var _createdEvents: [Event] = []

    var createError: Error? {
        get { stateQueue.sync { _createError } }
        set { stateQueue.sync { _createError = newValue } }
    }

    var createdEvents: [Event] {
        stateQueue.sync { _createdEvents }
    }

    func create(event: Event) throws {
        try stateQueue.sync {
            if let createError = _createError {
                throw createError
            }
            _createdEvents.append(event)
        }
    }

    func readEvent(by transactionId: String) throws -> Event? {
        createdEvents.first(where: { $0.transactionId == transactionId })
    }

    func update(event: Event) throws {}

    func delete(event: Event) throws {}

    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] {
        []
    }

    func removeDeprecatedEventsIfNeeded() throws {}

    func countDeprecatedEvents() throws -> Int {
        0
    }

    func erase() throws {
        stateQueue.sync {
            _createdEvents.removeAll()
        }
    }

    func countEvents() throws -> Int {
        createdEvents.count
    }
}

final class InAppPresentationErrorMappingTests: XCTestCase {
    func testFailureReasonMapping() {
        XCTAssertEqual(InAppPresentationError.failedToLoadImages.failureReason, .presentationFailed)
        XCTAssertEqual(InAppPresentationError.failedToLoadWindow.failureReason, .presentationFailed)
        XCTAssertEqual(InAppPresentationError.failed("details").failureReason, .presentationFailed)
        XCTAssertEqual(InAppPresentationError.webviewLoadFailed("details").failureReason, .webviewLoadFailed)
        XCTAssertEqual(InAppPresentationError.webviewPresentationFailed("details").failureReason, .webviewPresentationFailed)
    }

    func testFailureDetailsMapping() {
        XCTAssertEqual(
            InAppPresentationError.failedToLoadImages.failureDetails,
            "[InAppPresentationError] Failed to load images."
        )
        XCTAssertEqual(
            InAppPresentationError.failedToLoadWindow.failureDetails,
            "[InAppPresentationError] Failed to load window."
        )
        XCTAssertEqual(
            InAppPresentationError.failed("presentation-failed").failureDetails,
            "presentation-failed"
        )
        XCTAssertEqual(
            InAppPresentationError.webviewLoadFailed("webview-load").failureDetails,
            "webview-load"
        )
        XCTAssertEqual(
            InAppPresentationError.webviewPresentationFailed("webview-presentation").failureDetails,
            "webview-presentation"
        )
    }
}

final class PresentationDisplayUseCaseTests: XCTestCase {
    private var tracker: InAppMessagesTrackerMock!

    override func setUp() {
        super.setUp()
        tracker = InAppMessagesTrackerMock()
    }

    override func tearDown() {
        tracker = nil
        super.tearDown()
    }

    func testPresent_whenStrategyIsNotConfigured_callsOnError() {
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: nil, factory: nil) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Presentation strategy is not configured."
        )
    }

    func testPresent_whenWindowCreationFails_callsFailedToLoadWindow() {
        let strategy = PresentationStrategyMock(windowToReturn: nil, presentResult: true)
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: ViewFactoryMock(viewControllerToReturn: UIViewController())) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        guard case .failedToLoadWindow = receivedError else {
            return XCTFail("Expected .failedToLoadWindow, got \(String(describing: receivedError))")
        }
    }

    func testPresent_whenFactoryIsMissing_callsOnError() {
        let strategy = PresentationStrategyMock(windowToReturn: UIWindow(), presentResult: true)
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: nil) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Factory does not exist."
        )
    }

    func testPresent_whenFactoryCannotCreateViewController_callsOnError() {
        let strategy = PresentationStrategyMock(windowToReturn: UIWindow(), presentResult: true)
        let factory = ViewFactoryMock(viewControllerToReturn: nil)
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: factory) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Failed to create in-app view controller."
        )
    }

    func testPresent_whenStrategyPresentFails_callsOnError() {
        let strategy = PresentationStrategyMock(windowToReturn: UIWindow(), presentResult: false)
        let factory = ViewFactoryMock(viewControllerToReturn: UIViewController())
        let sut = PresentationDisplayUseCase(
            tracker: tracker,
            dependenciesResolver: { _ in (strategy: strategy, factory: factory) }
        )

        var receivedError: InAppPresentationError?
        sut.presentInAppUIModel(
            model: makeModalInApp(),
            onPresented: {},
            onTapAction: { _, _ in },
            onClose: {},
            onError: { receivedError = $0 }
        )

        assertFailedError(
            receivedError,
            details: "[PresentationDisplayUseCase] Failed to present in-app view controller."
        )
    }

    private func makeModalInApp() -> InAppFormData {
        let modal = ModalFormVariant(content: InappFormVariantContent(background: ContentBackground(layers: []), elements: nil))
        return InAppFormData(
            inAppId: "inapp-id",
            isPriority: false,
            delayTime: nil,
            imagesDict: [:],
            firstImageValue: "",
            content: .modal(modal),
            frequency: nil
        )
    }

    private func assertFailedError(_ error: InAppPresentationError?, details: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failed(let message) = error else {
            return XCTFail("Expected .failed(\(details)), got \(String(describing: error))", file: file, line: line)
        }
        XCTAssertEqual(message, details, file: file, line: line)
    }
}

final class SnackbarViewControllerTests: XCTestCase {
    func testLayout_whenImageIsMissing_reportsErrorAndCloses() {
        let model = makeSnackbarModel()
        let snackbarView = SnackbarView(onClose: {})

        var receivedError: InAppPresentationError?
        var closeCalls = 0
        let sut = TopSnackbarViewController(
            model: model,
            imagesDict: [:],
            snackbarView: snackbarView,
            firstImageValue: "missing-image",
            onPresented: {},
            onTapAction: { _, _ in },
            onError: { receivedError = $0 },
            onClose: { closeCalls += 1 }
        )

        sut.loadViewIfNeeded()
        sut.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        sut.viewDidLayoutSubviews()

        guard case .failedToLoadImages = receivedError else {
            return XCTFail("Expected .failedToLoadImages, got \(String(describing: receivedError))")
        }
        XCTAssertEqual(closeCalls, 1)
    }

    private func makeSnackbarModel() -> SnackbarFormVariant {
        let content = SnackbarFormVariantContent(
            background: ContentBackground(layers: []),
            position: ContentPosition(
                gravity: ContentPositionGravity(vertical: .top, horizontal: .center),
                margin: ContentPositionMargin(kind: .dp, top: 0, right: 0, left: 0, bottom: 0)
            ),
            elements: []
        )
        return SnackbarFormVariant(content: content)
    }
}

final class WebViewControllerWindowProviderTests: XCTestCase {
    func testOnInit_withInjectedWindowProvider_callsOnPresentedOnlyOnce() {
        let expectation = expectation(description: "onPresented is called once")
        expectation.expectedFulfillmentCount = 1

        let window = UIWindow()
        let model = makeModalVariant()
        let sut = WebViewController(
            model: model,
            id: "webview-id",
            imagesDict: [:],
            onPresented: {
                expectation.fulfill()
            },
            onTapAction: { _, _ in },
            onCloseInApp: {},
            onError: { _ in },
            windowProvider: { window },
            operation: nil
        )

        sut.onInit()
        sut.onInit()

        wait(for: [expectation], timeout: 1.0)
    }

    private func makeModalVariant() -> ModalFormVariant {
        ModalFormVariant(
            content: InappFormVariantContent(
                background: ContentBackground(layers: []),
                elements: nil
            )
        )
    }
}

private final class InAppMessagesTrackerMock: InAppMessagesTrackerProtocol {
    func trackView(id: String, timeToDisplay: String?, tags: [String: String]?) throws {}
    func trackClick(id: String) throws {}
}

private final class PresentationStrategyMock: PresentationStrategyProtocol {
    var window: UIWindow?
    private let windowToReturn: UIWindow?
    private let presentResult: Bool

    init(windowToReturn: UIWindow?, presentResult: Bool) {
        self.windowToReturn = windowToReturn
        self.presentResult = presentResult
    }

    func getWindow() -> UIWindow? {
        windowToReturn
    }

    func present(id: String, in window: UIWindow, using viewController: UIViewController) -> Bool {
        presentResult
    }

    func dismiss(viewController: UIViewController) {}

    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize) {}
}

private final class ViewFactoryMock: ViewFactoryProtocol {
    private let viewControllerToReturn: UIViewController?

    init(viewControllerToReturn: UIViewController?) {
        self.viewControllerToReturn = viewControllerToReturn
    }

    func create(with params: ViewFactoryParameters) -> UIViewController? {
        viewControllerToReturn
    }
}
