//
//  InAppMessagesTrackerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 01.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("InAppMessagesTracker tags gating tests")
final class InAppMessagesTrackerTests {
    private struct DecodedBody: Decodable {
        let inappId: String
        let timeToDisplay: String?
        let tags: [String: String]?
    }

    private let databaseRepository = InAppMessagesTrackerDatabaseRepositoryMock()
    private let featureToggleManager = FeatureToggleManager()
    private lazy var tracker = InAppMessagesTracker(databaseRepository: databaseRepository, featureToggleManager: featureToggleManager)

    private func decodedBody() -> DecodedBody? {
        guard let event = databaseRepository.createdEvents.first else { return nil }
        return BodyDecoder<DecodedBody>(decodable: event.body)?.body
    }

    @Test("trackView includes tags when the feature is enabled", .tags(.inAppTags))
    func trackViewIncludesTagsWhenEnabled() throws {
        try tracker.trackView(id: "inapp-1", timeToDisplay: "150", tags: ["templateType": "Popup"])
        #expect(decodedBody()?.tags == ["templateType": "Popup"])
    }

    @Test("trackView omits tags when the feature is disabled", .tags(.inAppTags))
    func trackViewOmitsTagsWhenDisabled() throws {
        applyTagsToggle(enabled: false)
        try tracker.trackView(id: "inapp-1", timeToDisplay: "150", tags: ["templateType": "Popup"])
        #expect(decodedBody()?.tags == nil)
    }

    @Test("trackClick includes tags when the feature is enabled", .tags(.inAppTags))
    func trackClickIncludesTagsWhenEnabled() throws {
        try tracker.trackClick(id: "inapp-2", tags: ["templateType": "Snackbar"])
        #expect(decodedBody()?.tags == ["templateType": "Snackbar"])
    }

    @Test("trackClick omits tags when the feature is disabled", .tags(.inAppTags))
    func trackClickOmitsTagsWhenDisabled() throws {
        applyTagsToggle(enabled: false)
        try tracker.trackClick(id: "inapp-2", tags: ["templateType": "Snackbar"])
        #expect(decodedBody()?.tags == nil)
    }

    @Test("trackTargeting includes tags when the feature is enabled", .tags(.inAppTags))
    func trackTargetingIncludesTagsWhenEnabled() throws {
        try tracker.trackTargeting(id: "inapp-3", tags: ["templateType": "Modal"])
        #expect(decodedBody()?.tags == ["templateType": "Modal"])
    }

    @Test("trackTargeting omits tags when the feature is disabled", .tags(.inAppTags))
    func trackTargetingOmitsTagsWhenDisabled() throws {
        applyTagsToggle(enabled: false)
        try tracker.trackTargeting(id: "inapp-3", tags: ["templateType": "Modal"])
        #expect(decodedBody()?.tags == nil)
    }

    @Test("trackClick omits tags when nil tags are passed", .tags(.inAppTags))
    func trackClickOmitsNilTags() throws {
        try tracker.trackClick(id: "inapp-4", tags: nil)
        #expect(decodedBody()?.tags == nil)
    }

    private func applyTagsToggle(enabled: Bool) {
        featureToggleManager.applyFeatureToggles(
            Settings.FeatureToggles(shouldSendInAppShowError: nil, shouldSendInAppTags: enabled)
        )
    }
}

private final class InAppMessagesTrackerDatabaseRepositoryMock: DatabaseRepositoryProtocol {
    var limit: Int = 0
    var lifeLimitDate: Date?
    var deprecatedLimit: Int = 0
    var onObjectsDidChange: (() -> Void)?
    private(set) var createdEvents: [Event] = []

    func create(event: Event) throws {
        createdEvents.append(event)
    }

    func readEvent(by transactionId: String) throws -> Event? {
        createdEvents.first(where: { $0.transactionId == transactionId })
    }

    func update(event: Event) throws {}
    func delete(event: Event) throws {}
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws {}
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws { createdEvents.removeAll() }
    func countEvents() throws -> Int { createdEvents.count }
}
