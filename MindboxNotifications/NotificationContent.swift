//
//  NotificationContent.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import UserNotificationsUI
import MindboxLogger

public protocol MindboxNotificationContentProtocol: MindboxPushNotificationProtocol {

    /// Call this method in `didReceive(_ notification: UNNotification)` of `NotificationViewController`
    func didReceive(
        notification: UNNotification,
        viewController: UIViewController,
        extensionContext: NSExtensionContext?
    )
}

// MARK: - MindboxNotificationContentProtocol

extension MindboxNotificationService: MindboxNotificationContentProtocol {

    /// Call this method in `didReceive(_ notification: UNNotification)` of `NotificationViewController`
    public func didReceive(notification: UNNotification, viewController: UIViewController, extensionContext: NSExtensionContext?) {
        context = extensionContext
        self.viewController = viewController

        createContent(for: notification, extensionContext: extensionContext)
    }
}

// MARK: Private methods for MindboxNotificationContentProtocol

private extension MindboxNotificationService {

    func createContent(for notification: UNNotification, extensionContext: NSExtensionContext?) {
        let request = notification.request
        guard let payload = parse(request: request) else {
            Logger.common(message: "[NotificationContent]: Failed to parse payload. request: \(request)", level: .error, category: .notification)
            return
        }

        if let attachment = notification.request.content.attachments.first,
           attachment.url.startAccessingSecurityScopedResource() {
            defer {
                attachment.url.stopAccessingSecurityScopedResource()
            }
            createImageView(with: attachment.url.path, view: viewController?.view)
        }
        createActions(with: payload, context: context)
    }

    func createActions(with payload: Payload, context: NSExtensionContext?) {
        guard let context = context, let buttons = payload.withButton?.buttons else {
            let message = "[NotificationContent]: Failed to create actions. payload: \(payload), context: \(String(describing: context)), payload.withButton?.buttons: \(String(describing: payload.withButton?.buttons))"
            Logger.common(message: message, level: .error, category: .notification)
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
                Logger.common(message: "[NotificationContent]: Button title: \($0.title), id: \($0.identifier)",
                              level: .info,
                              category: .notification)
                context.notificationActions.append($0)
            }
        }
    }

    func createImageView(with imagePath: String, view: UIView?) {
        guard let view = view,
              let data = FileManager.default.contents(atPath: imagePath) else {
            Logger.common(message: "[NotificationContent]: Failed to create view. imagePath: \(imagePath), view: \(String(describing: view))", level: .error, category: .notification)
            return
        }

        let image = UIImage(data: data)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let imageHeight = image?.size.height ?? 0
        let imageWidth = image?.size.width ?? 0

        let imageRatio = (imageWidth > 0) ? imageHeight / imageWidth : 0
        let imageViewHeight = view.bounds.width * imageRatio

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: imageViewHeight)
        ])
    }
}
