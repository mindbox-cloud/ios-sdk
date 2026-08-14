//
//  SettingsActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@_spi(Internal) @testable import Mindbox

@Suite("SettingsActionHandler", .tags(.webView))
@MainActor
struct SettingsActionHandlerTests {

    private func makeSUT(notificationsOpen: Bool = true)
    -> (handler: SettingsActionHandler, opener: URLOpenerSpy, host: HostSpy, notifications: NotificationSettingsSpy) {
        let opener = URLOpenerSpy()
        opener.result = true
        let notifications = NotificationSettingsSpy(result: notificationsOpen)
        let handler = SettingsActionHandler(urlOpener: opener,
                                            openNotificationSettings: notifications.open)
        return (handler, opener, HostSpy(), notifications)
    }

    @Test("Owns the settings.open action")
    func ownsSettingsOpen() {
        #expect(SettingsActionHandler().actions == [.settingsOpen])
    }

    /// Notification settings have their own route rather than the app's top-level page.
    @Test("The notifications target takes the notification route, not the URL one")
    func notificationsTargetUsesItsOwnRoute() async throws {
        let (handler, opener, host, notifications) = makeSUT()

        handler.handle(.request(.settingsOpen, payload: .object(["target": .string("notifications")])), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(notifications.callCount == 1)
        #expect(opener.opened.isEmpty)
        #expect(host.sent.first?.payload == .object(["success": .bool(true)]))
    }

    /// The page asked to be sent to settings and it was — whether the user then acts on it is
    /// not something the page is told.
    @Test("A notification route that reports failure is still answered as a success")
    func notificationsAnswerSuccessRegardless() async {
        let (handler, _, host, _) = makeSUT(notificationsOpen: false)

        handler.handle(.request(.settingsOpen, payload: .object(["target": .string("notifications")])), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(host.sent.first?.payload == .object(["success": .bool(true)]))
    }

    @Test("The application target opens the app's settings page through the system")
    func applicationTargetOpensSettingsURL() async throws {
        let (handler, opener, host, notifications) = makeSUT()

        handler.handle(.request(.settingsOpen, payload: .object(["target": .string("application")])), host: host)
        await drainMainQueue(until: { !host.sent.isEmpty })

        #expect(notifications.callCount == 0)
        #expect(opener.opened.first?.url.absoluteString == UIApplication.openSettingsURLString)
        #expect(host.sent.first?.payload == .object(["success": .bool(true)]))
    }

    @Test("An unknown target is refused without reaching the system")
    func unknownTargetIsRefused() throws {
        let (handler, opener, host, notifications) = makeSUT()

        handler.handle(.request(.settingsOpen, payload: .object(["target": .string("somewhere-else")])), host: host)

        #expect(opener.opened.isEmpty)
        #expect(notifications.callCount == 0)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid or unknown settings type")]))
    }

    @Test("A payload without a target is refused")
    func missingTargetIsRefused() throws {
        let (handler, _, host, _) = makeSUT()

        handler.handle(.request(.settingsOpen, payload: .object([:])), host: host)

        #expect(host.sent.first?.type == .error)
    }

    @Test("A payload sent as a JSON string is understood too")
    func acceptsStringifiedPayload() async {
        let (handler, opener, host, _) = makeSUT()

        handler.handle(.request(.settingsOpen, payload: .string("{\"target\":\"application\"}")), host: host)
        await drainMainQueue(until: { !opener.opened.isEmpty })

        #expect(opener.opened.count == 1)
    }

    // MARK: - Lifetime

    /// Both routes hold the page weakly, so a show that ended while the system was switching
    /// screens is not kept alive by the trip to settings.
    @Test("A page released mid-route is not held by the notification route")
    func notificationRouteDoesNotHoldPage() {
        let notifications = NotificationSettingsSpy(result: true, defersAnswer: true)
        let handler = SettingsActionHandler(urlOpener: URLOpenerSpy(),
                                            openNotificationSettings: notifications.open)

        var host: HostSpy? = HostSpy()
        let watch = ReleaseWatch(host!)

        handler.handle(.request(.settingsOpen, payload: .object(["target": .string("notifications")])), host: host!)
        #expect(notifications.callCount == 1)

        host = nil

        #expect(watch.isReleased)

        // The late answer finds nobody and is dropped rather than crashing.
        notifications.answer()
    }
}

// MARK: - Doubles

final class NotificationSettingsSpy {

    private let result: Bool

    /// Holds the answer back instead of giving it, standing in for the moment the system is still
    /// switching screens. That is the only window in which what the SDK holds onto is observable.
    private let defersAnswer: Bool

    private var pendingAnswer: ((Bool) -> Void)?

    private(set) var callCount = 0

    init(result: Bool, defersAnswer: Bool = false) {
        self.result = result
        self.defersAnswer = defersAnswer
    }

    func open(_ completion: @escaping (Bool) -> Void) {
        callCount += 1

        guard defersAnswer else {
            completion(result)
            return
        }

        pendingAnswer = completion
    }

    func answer() {
        let pendingAnswer = self.pendingAnswer
        self.pendingAnswer = nil
        pendingAnswer?(result)
    }
}
