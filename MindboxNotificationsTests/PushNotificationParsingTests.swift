//
//  PushNotificationParsingTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 6/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxNotifications

/// Exercises the push-format detection/parsing pipeline:
/// `NotificationStrategyFactory` → `LegacyFormatStrategy`/`CurrentFormatStrategy`
/// → `NotificationFormatter` → `MindboxPushValidator`.
@Suite("Push notification parsing pipeline", .tags(.notifications, .pushParsing))
struct PushNotificationParsingTests {

    // MARK: - NotificationStrategyFactory

    @Test("Factory selects the legacy strategy when aps carries clickUrl and uniqueKey")
    func factoryPicksLegacyStrategy() {
        let strategy = NotificationStrategyFactory.strategy(for: NotificationTestFixtures.legacyFormatUserInfo())
        #expect(strategy is LegacyFormatStrategy)
    }

    @Test("Factory selects the current strategy for a top-level payload")
    func factoryPicksCurrentStrategy() {
        let strategy = NotificationStrategyFactory.strategy(for: NotificationTestFixtures.currentFormatUserInfo())
        #expect(strategy is CurrentFormatStrategy)
    }

    @Test("Factory falls back to the current strategy without both legacy markers")
    func factoryFallsBackToCurrent() {
        let missingUniqueKey: [AnyHashable: Any] = ["aps": ["clickUrl": "https://mindbox.ru"]]
        let missingClickUrl: [AnyHashable: Any] = ["aps": ["uniqueKey": "abc"]]
        let neither: [AnyHashable: Any] = ["aps": ["alert": ["body": "hi"]]]
        let noAps: [AnyHashable: Any] = ["foo": "bar"]

        #expect(NotificationStrategyFactory.strategy(for: missingUniqueKey) is CurrentFormatStrategy)
        #expect(NotificationStrategyFactory.strategy(for: missingClickUrl) is CurrentFormatStrategy)
        #expect(NotificationStrategyFactory.strategy(for: neither) is CurrentFormatStrategy)
        #expect(NotificationStrategyFactory.strategy(for: noAps) is CurrentFormatStrategy)
    }

    // MARK: - LegacyFormatStrategy

    @Test("Legacy strategy maps a full payload into MBPushNotification")
    func legacyStrategyParsesFullPayload() throws {
        let result = try #require(LegacyFormatStrategy().handle(userInfo: NotificationTestFixtures.legacyFormatUserInfo()))
        #expect(result.clickUrl == NotificationTestFixtures.clickUrl)
        #expect(result.uniqueKey == NotificationTestFixtures.uniqueKey)
        #expect(result.imageUrl == NotificationTestFixtures.imageUrl)
        #expect(result.payload == NotificationTestFixtures.payloadString)
        #expect(result.aps?.alert?.title == "Test title")
        #expect(result.aps?.alert?.body == "Test description")
        #expect(result.aps?.sound == "default")
        #expect(result.aps?.mutableContent == 1)
        #expect(result.aps?.contentAvailable == 1)
        #expect(result.buttons?.count == 2)
        #expect(result.buttons?.first?.uniqueKey == NotificationTestFixtures.firstButtonKey)
        #expect(result.buttons?.first?.text == "Documentation")
    }

    @Test("Legacy strategy returns nil when the alert body is missing")
    func legacyStrategyRequiresBody() {
        #expect(LegacyFormatStrategy().handle(userInfo: NotificationTestFixtures.legacyFormatUserInfo(includeBody: false)) == nil)
    }

    @Test("Legacy strategy returns nil when clickUrl is missing")
    func legacyStrategyRequiresClickUrl() {
        #expect(LegacyFormatStrategy().handle(userInfo: NotificationTestFixtures.legacyFormatUserInfo(includeClickUrl: false)) == nil)
    }

    @Test("Legacy strategy rejects a current-format (top-level) payload")
    func legacyStrategyRejectsCurrentFormat() {
        #expect(LegacyFormatStrategy().handle(userInfo: NotificationTestFixtures.currentFormatUserInfo()) == nil)
    }

    @Test("Legacy strategy drops malformed buttons but keeps the notification")
    func legacyStrategyDropsMalformedButtons() throws {
        let aps: [String: Any] = [
            "alert": ["title": "t", "body": "b"],
            "clickUrl": "https://mindbox.ru",
            "uniqueKey": "key",
            "buttons": [
                ["text": "ok", "url": "https://a", "uniqueKey": "k1"],
                ["text": "missing url", "uniqueKey": "k2"]
            ]
        ]
        let result = try #require(LegacyFormatStrategy().handle(userInfo: ["aps": aps]))
        #expect(result.buttons?.count == 1)
        #expect(result.buttons?.first?.uniqueKey == "k1")
    }

    @Test("Legacy strategy yields nil buttons when the buttons array is absent")
    func legacyStrategyNilButtonsWhenAbsent() throws {
        let result = try #require(LegacyFormatStrategy().handle(userInfo: NotificationTestFixtures.legacyFormatUserInfo(includeButtons: false)))
        #expect(result.buttons == nil)
    }

    // MARK: - CurrentFormatStrategy

    @Test("Current strategy decodes a top-level payload")
    func currentStrategyParsesPayload() throws {
        let result = try #require(CurrentFormatStrategy().handle(userInfo: NotificationTestFixtures.currentFormatUserInfo()))
        #expect(result.clickUrl == NotificationTestFixtures.clickUrl)
        #expect(result.uniqueKey == NotificationTestFixtures.uniqueKey)
        #expect(result.imageUrl == NotificationTestFixtures.imageUrl)
        #expect(result.aps?.alert?.title == "Test title")
        #expect(result.aps?.alert?.body == "Test description")
        #expect(result.buttons?.count == 2)
    }

    @Test("Current strategy returns nil when clickUrl is missing")
    func currentStrategyRequiresClickUrl() {
        #expect(CurrentFormatStrategy().handle(userInfo: NotificationTestFixtures.currentFormatUserInfo(includeClickUrl: false)) == nil)
    }

    @Test("Current strategy returns nil when the alert body is missing")
    func currentStrategyRequiresBody() {
        #expect(CurrentFormatStrategy().handle(userInfo: NotificationTestFixtures.currentFormatUserInfo(includeBody: false)) == nil)
    }

    // MARK: - NotificationFormatter

    @Test("Formatter parses a current-format push")
    func formatterParsesCurrent() throws {
        let result = try #require(NotificationFormatter.formatNotification(NotificationTestFixtures.currentFormatUserInfo()))
        #expect(result.clickUrl == NotificationTestFixtures.clickUrl)
    }

    @Test("Formatter parses a legacy-format push")
    func formatterParsesLegacy() throws {
        let result = try #require(NotificationFormatter.formatNotification(NotificationTestFixtures.legacyFormatUserInfo()))
        #expect(result.uniqueKey == NotificationTestFixtures.uniqueKey)
    }

    @Test("Formatter returns nil for a non-Mindbox payload")
    func formatterReturnsNilForPlainPush() {
        #expect(NotificationFormatter.formatNotification(["aps": ["alert": ["body": "Just a plain push"]]]) == nil)
    }

    // MARK: - MindboxPushValidator

    @Test("Validator accepts current- and legacy-format Mindbox pushes")
    func validatorAcceptsMindboxPushes() {
        let validator = MindboxPushValidator()
        #expect(validator.isValid(item: NotificationTestFixtures.currentFormatUserInfo()))
        #expect(validator.isValid(item: NotificationTestFixtures.legacyFormatUserInfo()))
    }

    @Test("Validator rejects a non-Mindbox push")
    func validatorRejectsPlainPush() {
        #expect(!MindboxPushValidator().isValid(item: ["aps": ["alert": ["body": "plain"]]]))
    }
}
