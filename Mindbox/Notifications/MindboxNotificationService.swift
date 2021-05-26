//
//  MindboxNotificationService.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 26.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

public class MindboxNotificationService {
    // Public
    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?

    // Private
    private var context: NSExtensionContext?
    private var viewController: UIViewController?

    /// Mindbox proxy for NotificationsService and NotificationViewController
    public init() {}

    /// Call this method in `didReceive(_ notification: UNNotification)` of `NotificationViewController`
    public func didReceive(notification: UNNotification, viewController: UIViewController, extensionContext: NSExtensionContext?) {
        context = extensionContext
        self.viewController = viewController

        createContent(for: notification, extensionContext: extensionContext)
    }

    /// Call this method in `didReceive(_ request, withContentHandler)` of `NotificationService`
    public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        guard let bestAttemptContent = bestAttemptContent else { return }

        Mindbox.shared.pushDelivered(request: request)

        if let imageUrl = parse(request: request)?.withImageURL?.imageUrl,
           let allowedUrl = imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: allowedUrl) {
            downloadImage(with: url) { [weak self] in
                self?.proceedFinalStage(bestAttemptContent)
            }
        } else {
            proceedFinalStage(bestAttemptContent)
        }
    }

    private func downloadImage(with url: URL, completion: @escaping () -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            defer { completion() }
            guard let self = self else { return }
            guard let data = data else { return }

            if let attachment = self.saveImage(data) {
                self.bestAttemptContent?.attachments = [attachment]
            }
        }.resume()
    }

    private func proceedFinalStage(_ bestAttemptContent: UNMutableNotificationContent) {
        bestAttemptContent.categoryIdentifier = "MindBoxCategoryIdentifier"
        contentHandler?(bestAttemptContent)
    }

    /// Call this method in `serviceExtensionTimeWillExpire()` of `NotificationService`
    public func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent = bestAttemptContent {
            proceedFinalStage(bestAttemptContent)
        }
    }

    private func createContent(for notification: UNNotification, extensionContext: NSExtensionContext?) {
        let request = notification.request
        guard let payload = parse(request: request) else { return }

        if let attachment = notification.request.content.attachments.first,
           attachment.url.startAccessingSecurityScopedResource() {
            createImageView(with: attachment.url.path, view: viewController?.view)
        }
        createActions(with: payload, context: context)
    }

    private func createActions(with payload: Payload, context: NSExtensionContext?) {
        guard let context = context, let buttons = payload.withButton?.buttons else {
            return
        }
        let actions = buttons.map { button in
            UNNotificationAction(
                identifier: button.uniqueKey,
                title: button.text,
                options: [.foreground]
            )
        }

        if #available(iOS 12.0, *) {
            context.notificationActions = []
            actions.forEach {
                context.notificationActions.append($0)
            }
        }
    }

    private func createImageView(with imagePath: String, view: UIView?) {
        guard let view = view,
              let data = FileManager.default.contents(atPath: imagePath) else { return }

        let imageView = UIImageView(image: UIImage(data: data))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 300),
        ])
    }

    private func parse(request: UNNotificationRequest) -> Payload? {
        guard let userInfo = getUserInfo(from: request) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted) else { return nil }

        var payload = Payload()

        payload.withButton = try? JSONDecoder().decode(Payload.Button.self, from: data)
        payload.withImageURL = try? JSONDecoder().decode(Payload.ImageURL.self, from: data)

        return payload
    }

    private func getUserInfo(from request: UNNotificationRequest) -> [AnyHashable: Any]? {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            return nil
        }
        if userInfo.keys.count == 1, let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any] {
            return innerUserInfo
        } else {
            return userInfo
        }
    }

    private func saveImage(_ data: Data) -> UNNotificationAttachment? {
        let name = UUID().uuidString
        guard let format = ImageFormat(data) else {
            // not an image
            return nil
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = url.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let fileURL = directory.appendingPathComponent(name, isDirectory: true).appendingPathExtension(format.extension)
            try data.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: name, url: fileURL, options: nil)
        } catch {
            return nil
        }
    }
}

fileprivate struct Payload {
    struct ImageURL: Codable {
        let imageUrl: String?
    }

    struct Button: Codable {
        struct Buttons: Codable {
            let text: String
            let uniqueKey: String
        }

        let uniqueKey: String

        let buttons: [Buttons]?

        let imageUrl: String?

        var debugDescription: String {
            "uniqueKey: \(uniqueKey)"
        }
    }

    var withImageURL: ImageURL?
    var withButton: Button?
}

fileprivate enum ImageFormat: String {
    case png, jpg, gif

    init?(_ data: Data) {
        if let type = ImageFormat.get(from: data) {
            self = type
        } else {
            return nil
        }
    }

    var `extension`: String {
        return rawValue
    }
}

fileprivate extension ImageFormat {
    static func get(from data: Data) -> ImageFormat? {
        switch data[0] {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        default:
            return nil
        }
    }
}
