//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Дмитрий Ерофеев on 30.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    private let categoryIdentifier = "MindBoxCategoryIdentifier"
    private let lock = NSLock()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent,
              let push = PushNotification(userInfo: request.content.userInfo) else {
            contentHandler(request.content)
            return
        }
        
        lock.lock()
        self.contentHandler = contentHandler
        bestAttemptContent = content
        lock.unlock()

        content.categoryIdentifier = categoryIdentifier

        Task {
            await saveSwiftDataItem(push)
        }

        guard let imageURL = push.imageUrl.flatMap(Self.makeURL) else {
            finish(with: nil)
            return
        }
        URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, error in
            if let error {
                print("Failed to download push image: \(error.localizedDescription)")
            }
            self?.finish(with: data.flatMap(Self.makeAttachment))
        }.resume()
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        finish(with: nil)
    }

    private func finish(with attachment: UNNotificationAttachment?) {
        lock.lock()
        let handler = contentHandler
        let content = bestAttemptContent
        contentHandler = nil
        if handler != nil, let attachment {
            content?.attachments = [attachment]
        }
        lock.unlock()

        if let handler, let content {
            handler(content)
        }
    }

    private static func makeURL(from string: String) -> URL? {
        guard !string.isEmpty else {
            return nil
        }
        return URL(string: string) ?? string
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            .flatMap { URL(string: $0) }
    }

    private static func makeAttachment(from data: Data) -> UNNotificationAttachment? {
        guard let fileExtension = imageFileExtension(of: data) else {
            print("Push image is not PNG, JPEG or GIF")
            return nil
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("image").appendingPathExtension(fileExtension)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: "image", url: fileURL, options: nil)
        } catch {
            print("Failed to attach push image: \(error.localizedDescription)")
            return nil
        }
    }

    private static func imageFileExtension(of data: Data) -> String? {
        switch data.first {
        case 0x89:
            return "png"
        case 0xFF:
            return "jpg"
        case 0x47:
            return "gif"
        default:
            return nil
        }
    }
    
    @MainActor
    private func saveSwiftDataItem(_ push: PushNotification) async {
        let context = SwiftDataManager.shared.container.mainContext

        let newItem = Item(timestamp: Date(), pushNotification: push)
        
        context.insert(newItem)
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}

private extension PushNotification {
    init?(userInfo: [AnyHashable: Any]) {
        guard let uniqueKey = userInfo["uniqueKey"] as? String else {
            return nil
        }
        let alert = (userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
        self.init(
            title: alert?["title"] as? String,
            body: alert?["body"] as? String,
            clickUrl: userInfo["clickUrl"] as? String,
            imageUrl: userInfo["imageUrl"] as? String,
            payload: userInfo["payload"] as? String,
            uniqueKey: uniqueKey
        )
    }
}
