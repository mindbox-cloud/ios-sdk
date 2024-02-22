//
//  MindboxNotificationService.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 26.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import os
import MindboxLogger

@objcMembers
public class MindboxNotificationService: NSObject {
    // Public
    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?

    // Private
    private var context: NSExtensionContext?
    private var viewController: UIViewController?
    private let log = OSLog(subsystem: "cloud.Mindbox", category: "Notifications")

    /// Mindbox proxy for NotificationsService and NotificationViewController
    public override init() {
        super.init()
    }

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

        pushDelivered(request)
        
        Logger.common(message: "Push notification UniqueKey: \(request.identifier)", level: .info, category: .notification)

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
    
    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of NotificationService. This is necessary as an indicator that the push notification has been delivered to Mindbox services.
    public func pushDelivered(_ request: UNNotificationRequest) {
        let utilities = MBUtilitiesFetcher()
        guard let configuration = utilities.configuration else {
            Logger.error(.init(errorType: .internal, description: "Configuration is not set"))
            return
        }
        
        let networkService = NetworkService(utilitiesFetcher: utilities, configuration: configuration)
        let deliveryService = DeliveryService(utilitiesFetcher: utilities, networkService: networkService)
        
        do {
            try deliveryService.track(request: request)
        } catch {
            Logger.error(.init(errorType: .unknown, description: error.localizedDescription))
        }
    }

    private func downloadImage(with url: URL, completion: @escaping () -> Void) {
        Logger.common(message: "Image loading. [URL]: \(url)", level: .info, category: .notification)
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer { completion() }
            guard let self = self,
                  let data = data else {
                return
            }
            
            Logger.response(data: data, response: response, error: error)

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
                Logger.common(message: "Button title: \($0.title), id: \($0.identifier)",
                              level: .info,
                              category: .notification)
                context.notificationActions.append($0)
            }
        }
    }

    private func createImageView(with imagePath: String, view: UIView?) {
        guard let view = view,
              let data = FileManager.default.contents(atPath: imagePath) else { return }

        let imageView = UIImageView(image: UIImage(data: data))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let imageHeight = imageView.image?.size.height ?? 0
        let imageWidth = imageView.image?.size.width ?? 0
        let imageRatio = imageHeight / imageWidth
        let imageViewHeight = view.bounds.width * imageRatio
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: imageViewHeight),
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
            Logger.common(message: "Image load failed", level: .error, category: .notification)
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




