//
//  MindboxPushNotificationTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 6/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxNotifications

/// Covers the public `MindboxPushNotificationProtocol` surface on `MindboxNotificationService`
/// and `MBPushNotification` decoding.
@Suite("MindboxPushNotification public API", .tags(.notifications, .pushParsing))
struct MindboxPushNotificationTests {

    let service = MindboxNotificationService()

    // MARK: - isMindboxPush

    @Test("isMindboxPush is true for a current-format Mindbox push")
    func isMindboxPushTrueForCurrent() {
        #expect(service.isMindboxPush(userInfo: NotificationTestFixtures.currentFormatUserInfo()))
    }

    @Test("isMindboxPush is true for a legacy-format Mindbox push")
    func isMindboxPushTrueForLegacy() {
        #expect(service.isMindboxPush(userInfo: NotificationTestFixtures.legacyFormatUserInfo()))
    }

    @Test("isMindboxPush is false for a non-Mindbox push")
    func isMindboxPushFalseForPlain() {
        #expect(!service.isMindboxPush(userInfo: ["aps": ["alert": ["body": "plain"]]]))
    }

    @Test("isMindboxPush is false when no validator is configured")
    func isMindboxPushFalseWithoutValidator() {
        service.pushValidator = nil
        #expect(!service.isMindboxPush(userInfo: NotificationTestFixtures.currentFormatUserInfo()))
    }

    // MARK: - getMindboxPushData

    @Test("getMindboxPushData returns parsed data for a Mindbox push")
    func getMindboxPushDataReturnsModel() throws {
        let data = try #require(service.getMindboxPushData(userInfo: NotificationTestFixtures.currentFormatUserInfo()))
        #expect(data.clickUrl == NotificationTestFixtures.clickUrl)
        #expect(data.uniqueKey == NotificationTestFixtures.uniqueKey)
        #expect(data.aps?.alert?.body == "Test description")
    }

    @Test("getMindboxPushData returns nil for a non-Mindbox push")
    func getMindboxPushDataNilForPlain() {
        #expect(service.getMindboxPushData(userInfo: ["aps": ["alert": ["body": "plain"]]]) == nil)
    }

    // MARK: - MBPushNotification Codable

    @Test("MBPushNotification decodes nested aps keys with custom coding keys")
    func mbPushNotificationDecodes() throws {
        let json = """
        {
          "aps": {
            "alert": { "title": "T", "body": "B" },
            "sound": "default",
            "mutable-content": 1,
            "content-available": 1
          },
          "clickUrl": "https://mindbox.ru",
          "imageUrl": "https://img",
          "payload": "p",
          "uniqueKey": "uk",
          "buttons": [ { "text": "ok", "url": "https://a", "uniqueKey": "bk" } ]
        }
        """
        let model = try JSONDecoder().decode(MBPushNotification.self, from: Data(json.utf8))
        #expect(model.clickUrl == "https://mindbox.ru")
        #expect(model.imageUrl == "https://img")
        #expect(model.payload == "p")
        #expect(model.uniqueKey == "uk")
        #expect(model.aps?.alert?.title == "T")
        #expect(model.aps?.alert?.body == "B")
        #expect(model.aps?.sound == "default")
        #expect(model.aps?.mutableContent == 1)
        #expect(model.aps?.contentAvailable == 1)
        #expect(model.buttons?.count == 1)
        #expect(model.buttons?.first?.text == "ok")
        #expect(model.buttons?.first?.url == "https://a")
        #expect(model.buttons?.first?.uniqueKey == "bk")
    }

    @Test("MBPushNotification tolerates absent optional fields")
    func mbPushNotificationDecodesMinimal() throws {
        let model = try JSONDecoder().decode(MBPushNotification.self, from: Data("{}".utf8))
        #expect(model.aps == nil)
        #expect(model.clickUrl == nil)
        #expect(model.buttons == nil)
    }
}
