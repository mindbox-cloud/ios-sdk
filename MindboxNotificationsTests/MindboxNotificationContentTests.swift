//
//  MindboxNotificationContentTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 8/13/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
import UserNotifications
@testable import MindboxNotifications

@MainActor
@Suite("MindboxNotificationService (NotificationContent extension)", .tags(.notifications, .notificationContent))
struct MindboxNotificationContentTests {

    let service = MindboxNotificationService()
    let viewController = UIViewController()

    @Test("didReceive wires up the view controller, image view and button actions")
    func didReceiveBuildsContentImageAndActions() throws {
        let content = NotificationTestFixtures.makeContent(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(),
            title: "Test title",
            body: "Test description"
        )
        content.attachments = [try NotificationTestFixtures.makeImageAttachment()]
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
        let notification = MockUNNotification(request: request)
        let context = MockExtensionContext()

        #expect(!notification.request.content.attachments.isEmpty)

        service.didReceive(notification: notification, viewController: viewController, extensionContext: context)

        #expect(service.viewController === viewController)
        #expect(service.context === context)

        #expect(service.context?.notificationActions.count == 2)
        let actionTitles = service.context?.notificationActions.map { $0.title }
        #expect(actionTitles?.contains("Documentation") == true)
        #expect(actionTitles?.contains("Button #1") == true)

        let imageView = viewController.view.subviews.first { $0 is UIImageView }
        #expect(imageView != nil, "The UIImageView should be added to the view controller")
    }

    @Test("A GIF attachment shows its first frame at once and then plays the next frames")
    func gifAttachmentStartsOnFirstFrameThenAnimates() async throws {
        let content = NotificationTestFixtures.makeContent(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        content.attachments = [try NotificationTestFixtures.makeGIFAttachment(colors: [.red, .blue])]
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)

        service.didReceive(
            notification: MockUNNotification(request: request),
            viewController: viewController,
            extensionContext: MockExtensionContext()
        )

        let imageView = try #require(viewController.view.subviews.compactMap { $0 as? UIImageView }.first)
        #expect(centrePixel(of: imageView.image) == .red)
        let reachedSecondFrame = await waitUntil { centrePixel(of: imageView.image) == .blue }
        #expect(reachedSecondFrame)
    }

    @Test("didReceive creates actions but no image view when there is no attachment")
    func didReceiveButtonsNoAttachment() {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        let notification = MockUNNotification(request: request)
        let context = MockExtensionContext()

        service.didReceive(notification: notification, viewController: viewController, extensionContext: context)

        #expect(service.context?.notificationActions.count == 2)
        let hasImageView = viewController.view.subviews.contains { $0 is UIImageView }
        #expect(!hasImageView)
    }

    @Test("didReceive creates no actions when the payload has no buttons")
    func didReceiveNoButtons() {
        let request = NotificationTestFixtures.makeRequest(
            userInfo: NotificationTestFixtures.currentFormatUserInfo(includeButtons: false)
        )
        let notification = MockUNNotification(request: request)
        let context = MockExtensionContext()

        service.didReceive(notification: notification, viewController: viewController, extensionContext: context)

        #expect(service.context?.notificationActions.isEmpty == true)
    }

    @Test("didReceive without an extension context creates no actions and does not crash")
    func didReceiveNilContext() {
        let request = NotificationTestFixtures.makeRequest(userInfo: NotificationTestFixtures.currentFormatUserInfo())
        let notification = MockUNNotification(request: request)

        service.didReceive(notification: notification, viewController: viewController, extensionContext: nil)

        #expect(service.context == nil)
        #expect(service.viewController === viewController)
    }

    private enum PixelColour {
        case red, blue, other
    }

    private func centrePixel(of image: UIImage?) -> PixelColour? {
        guard let cgImage = image?.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        switch (pixel[0], pixel[2]) {
        case (200..., ..<60): return .red
        case (..<60, 200...): return .blue
        default: return .other
        }
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return true
    }
}
