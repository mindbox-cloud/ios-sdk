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
    public var date = Date()
    
    // Private
    private var context: NSExtensionContext?
    private var viewController: UIViewController?
    private var attachmentUrl: URL?
    private let dispatchGroup = DispatchGroup()
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
        date = Date()
        
        dispatchGroup.enter()
        dispatchGroup.enter()
       
        DispatchQueue.init(label: "asd", qos: .utility).async { [weak self] in
            let date = Date()
            Mindbox.shared.pushDelivered(request: request)
            bestAttemptContent.title += "\(Date().timeIntervalSince(date))"
            self?.dispatchGroup.leave()
        }
        
        
        if let imageUrl = self.parse(request: request)?.withImageURL?.imageUrl,
           let allowedUrl = imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: allowedUrl) {
            downloadImage(with: url)
        } else {
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            Mindbox.logger.log(level: .default, message: "NOTIFY")
            self.proceedFinalStage(bestAttemptContent)
        }
    }
    
    private func downloadImage(with url: URL) {
        let date = Date()
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data else {
                self.dispatchGroup.leave()
                return
            }
            if let attachment = self.saveImage(url.lastPathComponent, data: data, options: nil) {
                self.bestAttemptContent?.attachments = [attachment]
            }
            self.bestAttemptContent?.body = "\(Date().timeIntervalSince(date))"
            self.dispatchGroup.leave()
        }.resume()
    }
    
    private func proceedFinalStage(_ bestAttemptContent: UNMutableNotificationContent) {
        bestAttemptContent.categoryIdentifier = "MindBoxCategoryIdentifier"
        //showSeconds(for: bestAttemptContent)
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
            attachmentUrl = attachment.url
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
    
    private func showSeconds(for content: UNMutableNotificationContent) {
        let delta = Date().timeIntervalSince(date)
        let ms = Int64((delta * 1000).rounded())
        let s = Int64(ms / 1000)
        let remainsMS = s > 0 ? (ms - s * 1000) : ms
        content.title = "\(content.title) \(s)s \(remainsMS)ms"
    }
    
    private func saveImage(_ identifire: String, data: Data, options: [AnyHashable: Any]?) -> UNNotificationAttachment? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = url.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let fileURL = directory.appendingPathComponent(identifire)
            try data.write(to: fileURL, options: [])
            return try UNNotificationAttachment(identifier: identifire, url: fileURL, options: options)
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
