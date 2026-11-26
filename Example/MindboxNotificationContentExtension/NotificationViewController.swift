//
//  NotificationViewController.swift
//  MindboxNotificationContentExtension
//
//  Created by Дмитрий Ерофеев on 31.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        if let attachment = content.attachments.first {
            showImage(from: attachment.url)
        }
        extensionContext?.notificationActions = makeActions(from: content.userInfo)
    }
    
    private func makeActions(from userInfo: [AnyHashable: Any]) -> [UNNotificationAction] {
        let buttons = userInfo["buttons"] as? [[String: Any]] ?? []
        return buttons.compactMap { button in
            guard let uniqueKey = button["uniqueKey"] as? String,
                  let text = button["text"] as? String else {
                return nil
            }
            return UNNotificationAction(identifier: uniqueKey, title: text, options: [.foreground])
        }
    }

    private func showImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        guard let data = FileManager.default.contents(atPath: url.path),
              let image = UIImage(data: data),
              image.size.width > 0 else {
            return
        }

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let imageViewHeight = view.bounds.width * image.size.height / image.size.width
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: imageViewHeight)
        ])
    }
}
