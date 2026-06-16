//
//  SharedInternalMethodsTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 8/13/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UserNotifications
@testable import MindboxNotifications

@Suite("SharedInternalMethods", .tags(.notifications, .pushParsing))
struct SharedInternalMethodsTests {

    let service = MindboxNotificationService()

    // MARK: - parse(request:)

    @Test("parse maps a current-format request into a Payload")
    func parseCurrentFormat() throws {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        let payload = try #require(service.parse(request: request))

        let button = try #require(payload.withButton)
        #expect(button.buttons?.first?.uniqueKey == NotificationTestFixtures.firstButtonKey)
        #expect(button.buttons?.first?.text == "Documentation")
        #expect(button.buttons?.last?.uniqueKey == NotificationTestFixtures.secondButtonKey)
        #expect(button.buttons?.last?.text == "Button #1")
        #expect(payload.withImageURL?.imageUrl == NotificationTestFixtures.imageUrl)
    }

    @Test("Payload.Button.debugDescription includes the unique key")
    func payloadButtonDebugDescription() throws {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        let button = try #require(service.parse(request: request)?.withButton)
        #expect(button.debugDescription == "uniqueKey: \(button.uniqueKey)")
    }

    // parse(request:)'s nil paths are unreachable here: getUserInfo never returns nil, and the
    // only JSONSerialization failures throw an ObjC exception that `try?` can't catch (it crashes).

    // MARK: - getUserInfo(from:)

    @Test("getUserInfo returns the outer payload for the current format")
    func getUserInfoCurrentFormat() throws {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        let result = try #require(service.getUserInfo(from: request))

        #expect(result["uniqueKey"] as? String == NotificationTestFixtures.uniqueKey)
        #expect(result["clickUrl"] as? String == NotificationTestFixtures.clickUrl)

        let aps = try #require(result["aps"] as? [AnyHashable: Any])
        #expect(aps["sound"] as? String == "default")
        #expect(aps["mutable-content"] as? Int == 1)
        #expect(aps["content-available"] as? Int == 1)

        let alert = try #require(aps["alert"] as? [String: String])
        #expect(alert["title"] == "Test title")
        #expect(alert["body"] == "Test description")
    }

    @Test("getUserInfo unwraps the aps dictionary for the legacy format")
    func getUserInfoLegacyFormat() throws {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.legacyFormatUserInfo())
        let result = try #require(service.getUserInfo(from: request))

        #expect(result["uniqueKey"] as? String == NotificationTestFixtures.uniqueKey)
        #expect(result["clickUrl"] as? String == NotificationTestFixtures.clickUrl)
        #expect(result["sound"] as? String == "default")
        #expect(result["mutable-content"] as? Int == 1)
        #expect(result["content-available"] as? Int == 1)

        let alert = try #require(result["alert"] as? [String: String])
        #expect(alert["title"] == "Test title")
        #expect(alert["body"] == "Test description")
    }
}
