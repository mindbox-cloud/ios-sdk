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
        guard let bestAttemptContent = bestAttemptContent else {
            Logger.common(message: "MindboxNotificationService: Failed to get bestAttemptContent. bestAttemptContent: \(String(describing: bestAttemptContent))", level: .error, category: .notification)
            return
        }

        pushDelivered(request)

        Logger.common(message: "Push notification UniqueKey: \(request.identifier)", level: .info, category: .notification)

        if let imageUrl = parse(request: request)?.withImageURL?.imageUrl,
           let allowedUrl = imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: allowedUrl) {
            downloadImage(with: url) { [weak self] in
                self?.proceedFinalStage(bestAttemptContent)
            }
        } else {
            Logger.common(message: "MindboxNotificationService: Failed to parse imageUrl", level: .error, category: .notification)
            proceedFinalStage(bestAttemptContent)
        }
    }

    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of NotificationService. This is necessary as an indicator that the push notification has been delivered to Mindbox services.
    public func pushDelivered(_ request: UNNotificationRequest) {
        let utilities = MBUtilitiesFetcher()
        guard let configuration = utilities.configuration else {
            Logger.common(message: "MindboxNotificationService: Failed to get configuration. utilities.configuration: \(String(describing: utilities.configuration))", level: .error, category: .notification)
            return
        }
        Logger.common(message: "MindboxNotificationService: Successfully received configuration. configuration: \(configuration)", level: .info, category: .notification)
        
        let networkService = NetworkService(utilitiesFetcher: utilities, configuration: configuration)
        let deliveryService = DeliveryService(utilitiesFetcher: utilities, networkService: networkService)

        do {
            try deliveryService.track(request: request)
            Logger.common(message: "MindboxNotificationService: Successfully tracked. request: \(request)", level: .info, category: .notification)
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
                Logger.common(message: "MindboxNotificationService: Failed to get self or data. self: \(String(describing: self)), data: \(String(describing: data))", level: .error, category: .notification)
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
            Logger.common(message: "MindboxNotificationService: Failed to get bestAttemptContent. bestAttemptContent: \(bestAttemptContent)", level: .error, category: .notification)
            proceedFinalStage(bestAttemptContent)
        }
    }

    private func createContent(for notification: UNNotification, extensionContext: NSExtensionContext?) {
        let request = notification.request
        guard let payload = parse(request: request) else {
            Logger.common(message: "MindboxNotificationService: Failed to parse payload. request: \(request)", level: .error, category: .notification)
            return
        }

        if let attachment = notification.request.content.attachments.first,
           attachment.url.startAccessingSecurityScopedResource() {
            createImageView(with: attachment.url.path, view: viewController?.view)
        }
        createActions(with: payload, context: context)
    }

    private func createActions(with payload: Payload, context: NSExtensionContext?) {
        guard let context = context, let buttons = payload.withButton?.buttons else {
            Logger.common(message: "MindboxNotificationService: Failed to create actions. payload: \(payload), context: \(String(describing: context)), payload.withButton?.buttons: \(String(describing: payload.withButton?.buttons))", level: .error, category: .notification)
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
              let data = FileManager.default.contents(atPath: imagePath) else {
            Logger.common(message: "MindboxNotificationService: Failed to create view. imagePath: \(imagePath), view: \(String(describing: view))", level: .error, category: .notification)
            return
        }

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
        guard let userInfo = getUserInfo(from: request) else {
            Logger.common(message: "MindboxNotificationService: Failed to get userInfo", level: .error, category: .notification)
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted) else {
            Logger.common(message: "MindboxNotificationService: Failed to get data. userInfo: \(userInfo)", level: .error, category: .notification)
            return nil
        }

        var payload = Payload()

        payload.withButton = try? JSONDecoder().decode(Payload.Button.self, from: data)
        Logger.common(message: "MindboxNotificationService: payload.withButton: \(String(describing: payload.withButton))", level: .info, category: .notification)
        
        payload.withImageURL = try? JSONDecoder().decode(Payload.ImageURL.self, from: data)
        Logger.common(message: "MindboxNotificationService: payload.withImageURL: \(String(describing: payload.withImageURL))", level: .info, category: .notification)
        
        return payload
    }

    private func getUserInfo(from request: UNNotificationRequest) -> [AnyHashable: Any]? {
        guard let userInfo = (request.content.mutableCopy() as? UNMutableNotificationContent)?.userInfo else {
            Logger.common(message: "MindboxNotificationService: Failed to get userInfo", level: .error, category: .notification)
            return nil
        }
        if userInfo.keys.count == 1, let innerUserInfo = userInfo["aps"] as? [AnyHashable: Any] {
            Logger.common(message: "MindboxNotificationService: userInfo: \(innerUserInfo), userInfo.keys.count: \(userInfo.keys.count), innerUserInfo: \(innerUserInfo)", level: .info, category: .notification)
            return innerUserInfo
        } else {
            Logger.common(message: "MindboxNotificationService: userInfo: \(userInfo)", level: .info, category: .notification)
            return userInfo
        }
    }

    private func saveImage(_ data: Data) -> UNNotificationAttachment? {
        let name = UUID().uuidString
        guard let format = ImageFormat(data) else {
            Logger.common(message: "MindboxNotificationService: Image load failed, data: \(data)", level: .error, category: .notification)
            return nil
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = url.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            Logger.common(message: "MindboxNotificationService: Successfully created directory", level: .info, category: .notification)
            let fileURL = directory.appendingPathComponent(name, isDirectory: true).appendingPathExtension(format.extension)
            try data.write(to: fileURL, options: .atomic)
            Logger.common(message: "MindboxNotificationService: Successfully data written", level: .info, category: .notification)
            return try UNNotificationAttachment(identifier: name, url: fileURL, options: nil)
        } catch {
            Logger.common(message: "MindboxNotificationService: Failed to save image. data: \(data), name: \(name), url: \(url), directory: \(directory)", level: .error, category: .notification)
            return nil
        }
    }
}




