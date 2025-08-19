//
//  NotificationService.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

public protocol MindboxNotificationServiceProtocol: MindboxPushNotificationProtocol {

    var contentHandler: ((UNNotificationContent) -> Void)? { get set }
    var bestAttemptContent: UNMutableNotificationContent? { get set }

    /// Call this method in `didReceive(_ request, withContentHandler)` of `NotificationService`
    func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    )

    /// Call this method in `serviceExtensionTimeWillExpire()` of `NotificationService`
    func serviceExtensionTimeWillExpire()

    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of `NotificationService`. 
    /// This is necessary as an indicator that the push notification has been delivered to Mindbox services.
    /// At the moment, this method only writes a push delivery log.
    func pushDelivered(_ request: UNNotificationRequest)
}

// MARK: - MindboxNotificationServiceProtocol

extension MindboxNotificationService: MindboxNotificationServiceProtocol {

    /// Call this method in `didReceive(_ request, withContentHandler)` of `NotificationService`
    public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        guard let bestAttemptContent = bestAttemptContent else {
            return
        }

        pushDelivered(request)

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

    /// Call this method in `serviceExtensionTimeWillExpire()` of `NotificationService`
    public func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent = bestAttemptContent {
            proceedFinalStage(bestAttemptContent)
        }
    }

    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of NotificationService.
    /// This is necessary as an indicator that the push notification has been delivered to Mindbox services.
    /// At the moment, this method only writes a push delivery log.
    public func pushDelivered(_ request: UNNotificationRequest) {
        let message = "[NotificationService] \(#function), request id: \(request.identifier)"
        print(message)
    }
}

// MARK: Private methods for MindboxNotificationServiceProtocol

private extension MindboxNotificationService {
    func downloadImage(with url: URL, completion: @escaping () -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            defer { completion() }
            guard let self = self,
                  let data = data else {
                return
            }

            if let attachment = self.saveImage(data) {
                self.bestAttemptContent?.attachments = [attachment]
            }
        }.resume()
    }

    func saveImage(_ data: Data) -> UNNotificationAttachment? {
        let name = UUID().uuidString
        guard let format = ImageFormat(data) else {
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

    func proceedFinalStage(_ bestAttemptContent: UNMutableNotificationContent) {
        bestAttemptContent.categoryIdentifier = Constants.categoryIdentifier
        contentHandler?(bestAttemptContent)
    }
}
