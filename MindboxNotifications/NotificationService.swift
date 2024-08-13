//
//  NotificationService.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications
import MindboxLogger

public protocol MindboxNotificationServiceProtocol {
    var contentHandler: ((UNNotificationContent) -> Void)? { get set }
    var bestAttemptContent: UNMutableNotificationContent? { get set }
    
    /// Call this method in `didReceive(_ request, withContentHandler)` of `NotificationService`
    func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    )
    
    /// Call this method in `serviceExtensionTimeWillExpire()` of `NotificationService`
    func serviceExtensionTimeWillExpire()
    
    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of `NotificationService`. This is necessary as an indicator that the push notification has been delivered to Mindbox services.
    func pushDelivered(_ request: UNNotificationRequest)
}

// MARK: - MindboxNotificationServiceProtocol

extension MindboxNotificationService: MindboxNotificationServiceProtocol {
    
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
    
    /// Call this method in `serviceExtensionTimeWillExpire()` of `NotificationService`
    public func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent = bestAttemptContent {
            Logger.common(message: "MindboxNotificationService: Failed to get bestAttemptContent. bestAttemptContent: \(bestAttemptContent)", level: .error, category: .notification)
            proceedFinalStage(bestAttemptContent)
        }
    }
    
    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of NotificationService. This is necessary as an indicator that the push notification has been delivered to Mindbox services.
    public func pushDelivered(_ request: UNNotificationRequest) {
        let message = "[NotificationService]: \(#function), request id: \(request.identifier)"
        Logger.common(message: message, level: .info, category: .notification)
    }
}

// MARK: Private methods for MindboxNotificationServiceProtocol

private extension MindboxNotificationService {
    func downloadImage(with url: URL, completion: @escaping () -> Void) {
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
    
    func saveImage(_ data: Data) -> UNNotificationAttachment? {
        let name = UUID().uuidString
        guard let format = ImageFormat(data) else {
            Logger.common(message: "MindboxNotificationService: Image load failed, data: \(data)", level: .error, category: .notification)
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
            Logger.common(message: "MindboxNotificationService: Failed to save image. data: \(data), name: \(name), url: \(url), directory: \(directory)", level: .error, category: .notification)
            return nil
        }
    }
    
    func proceedFinalStage(_ bestAttemptContent: UNMutableNotificationContent) {
        bestAttemptContent.categoryIdentifier = Constants.categoryIdentifier
        contentHandler?(bestAttemptContent)
    }
}
