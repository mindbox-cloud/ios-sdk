//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Дмитрий Ерофеев on 30.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UserNotifications
import MindboxNotifications
import MindboxLogger

final class NotificationService: UNNotificationServiceExtension {

    lazy var mindboxService: MindboxNotificationServiceProtocol = MindboxNotificationService()
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let userInfo = request.content.userInfo

        // Проверяем, что push-уведомление пришло от Mindbox
        if mindboxService.isMindboxPush(userInfo: userInfo),
           let mindboxPushNotification = mindboxService.getMindboxPushData(userInfo: userInfo),
           let identifier = mindboxPushNotification.uniqueKey {

            // Проверяем, что в payload push-уведомления лежит структура в нужном формате и пытаемся запланировать локальное уведомление
            if let payload = mindboxPushNotification.payload?.data(using: .utf8),
               let localPush = MBLocalPushNotification.decode(from: payload),
               let rawUserInfo = try? JSONSerialization.jsonObject(with: payload, options: []) as? [AnyHashable: Any] {

                scheduleCalendarNotification(localPush: localPush, identifier: identifier, rawUserInfo: rawUserInfo)
            } else {
                Logger.common(message: "[SchedulingPush]: Can't schedule local push notification. The payload does not contain the required data \(String(describing: mindboxPushNotification.payload))",
                              category: .notification)
            }

            Task {
                await saveSwiftDataItem(mindboxPushNotification)
            }
        }

        mindboxService.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        mindboxService.serviceExtensionTimeWillExpire()
    }
}

// MARK: - Schedule Local Push Notification

private extension NotificationService {

    /// Создание отложенного push-уведомления на определенное время
    /// - Parameters:
    ///   - localPush: Модель локального push-уведомления, полученная из payload удаленного push-уведомления.
    ///   - identifier: Уникальный идентификатор push-уведомления, обычно берется из удаленного push-уведомления.
    ///   - rawUserInfo: "Сырой" словарь данных из payload удаленного push-уведомления, который используется для передачи данных в `NotificationViewController` и обработки в `userNotificationCenter(_:didReceive:withCompletionHandler:)`.
    /// - Note: Уведомление будет запланировано только если указанная дата находится в будущем.
    func scheduleCalendarNotification(localPush: MBLocalPushNotification, identifier: String, rawUserInfo: [AnyHashable: Any]) {
        let timestamp = localPush.showTimeGTM
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: timestamp) else {
            Logger.common(message: "[SchedulingPush]: Can't create date from showTimeGTM: \(timestamp)", level: .error, category: .notification)
            return
        }
        let now = Date()

        let logMessage = "[SchedulingPush]: An attempt to schedule a local notification. Date from server: \(timestamp). Date from server UTC: \(date). Current date UTC: \(now). Current Time Zone: \(TimeZone.current)"
        Logger.common(message: logMessage, category: .notification)

        guard date > now else {
            Logger.common(message: "[SchedulingPush]: Can't schedule a local notification for the past. Date from server: \(timestamp). Date from server UTC: \(date). Current date UTC: \(now)", category: .notification)
            return
        }

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        Logger.common(message: "[SchedulingPush]: Scheduling local notification at local time: \(dateComponents)", category: .notification)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = localPush.pushData.aps?.alert?.title ?? ""
        content.body = localPush.pushData.aps?.alert?.body ?? ""
        content.categoryIdentifier = "MindBoxCategoryIdentifier"
        content.userInfo = updateUserInfo(rawUserInfo: rawUserInfo, uniqueKey: identifier)

        if let imageUrlString = localPush.pushData.imageUrl, let imageUrl = URL(string: imageUrlString) {
            downloadImage(with: imageUrl) { [weak self] attachment in
                if let attachment = attachment {
                    content.attachments = [attachment]
                }

                self?.addRequestWith(identifier: identifier, content: content, trigger: trigger)
            }
        } else {
            addRequestWith(identifier: identifier, content: content, trigger: trigger)
        }
    }

    /// Создание и добавление планируемого локального push-уведомления в центр уведомлений `UNUserNotificationCenter`.
    /// - Parameters:
    ///   - identifier: Уникальный идентификатор уведомления, используемый для управления запросами.
    ///   - content: Данные push-уведомления, включая заголовок, текст, вложения и дополнительные параметры.
    ///   - trigger: Триггер, определяющий момент показа уведомления. В данной реализации используется `UNCalendarNotificationTrigger`.
    /// - Note: В случае ошибки планирования уведомления выводится сообщение в консоль.
    func addRequestWith(identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.common(message: "[SchedulingPush]: Error scheduling local notification: \(error.localizedDescription)",
                              level: .error, category: .notification)
            } else {
                Logger.common(message: "[SchedulingPush]: Local notification scheduled successfully. Content userInfo: \(content.userInfo)",
                              category: .notification)
            }
        }
    }

    /// Обновление словаря `userInfo` для локального push-уведомления.
    /// Добавляет уникальный идентификатор для уведомления и уникальные ключи для каждой кнопки, если они присутствуют.
    /// - Parameters:
    ///   - rawUserInfo: Исходный словарь данных из payload удаленного push-уведомления.
    ///   - uniqueKey: Уникальный идентификатор push-уведомления.
    /// - Returns: Обновленный словарь `userInfo` с добавленными уникальными ключами.
    func updateUserInfo(rawUserInfo: [AnyHashable: Any], uniqueKey: String) -> [AnyHashable: Any] {
        Logger.common(message: "[SchedulingPush]: userInfo before changes: \(rawUserInfo)", category: .notification)
        var localUserInfo = rawUserInfo

        localUserInfo["uniqueKey"] = uniqueKey

        if var buttons = localUserInfo["buttons"] as? [[String: Any]] {
            for index in buttons.indices {
                buttons[index]["uniqueKey"] = UUID().uuidString
            }
            localUserInfo["buttons"] = buttons
        }

        let finalUserInfo: [AnyHashable: Any] = localUserInfo.reduce(into: [:]) { result, keyValue in
            result[AnyHashable(keyValue.key)] = keyValue.value
        }

        Logger.common(message: "[SchedulingPush]: userInfo after update: \(finalUserInfo)", category: .notification)
        return finalUserInfo
    }

    /// Загрузка изображения по указанному URL.
    /// - Parameters:
    ///   - url: URL изображения для загрузки.
    ///   - completion: Замыкание, вызываемое после завершения загрузки. Передает объект `UNNotificationAttachment`, если загрузка и создание вложения выполнены успешно, иначе — `nil`.
    func downloadImage(with url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        Logger.common(message: "[SchedulingPush]: An attempt to download image for scheduling push notification with url: \(url.absoluteString)",
                      category: .notification)
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                Logger.common(message: "[SchedulingPush]: Failed to download image: \(error?.localizedDescription ?? "Unknown error")",
                              level: .error, category: .notification)
                completion(nil)
                return
            }

            if let mimeType = response?.mimeType {
                Logger.common(message: "[SchedulingPush]: Downloading MIME Type: \(mimeType)", category: .notification)
            }

            let attachment = self.saveImage(data)

            Logger.common(message: "[SchedulingPush]: Image successfully downloaded", category: .notification)
            completion(attachment)
        }.resume()
    }

    /// Сохранение загруженных данных изображения в файловую систему для использования в push-уведомлении.
    /// - Parameter data: "Сырые" данные изображения.
    /// - Returns: Объект `UNNotificationAttachment`, если сохранение прошло успешно. Возвращает `nil`, если произошла ошибка.
    /// - Note: Создает временную директорию для хранения изображения. Логирует ошибки в случае неудачи.
    func saveImage(_ data: Data) -> UNNotificationAttachment? {
        Logger.common(message: "[SchedulingPush]: An attempt to save image for scheduling push notification", category: .notification)
        guard let imageFormat = ImageFormat(data) else {
            Logger.common(message: "[SchedulingPush]: Failed to detect image format", level: .error, category: .notification)
            return nil
        }

        let fileName = UUID().uuidString

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let uniqueDirectory = temporaryDirectory.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: uniqueDirectory, withIntermediateDirectories: true, attributes: nil)
            let fileURL = uniqueDirectory.appendingPathComponent(fileName).appendingPathExtension(imageFormat.extension)
            try data.write(to: fileURL, options: .atomic)
            let attachment = try UNNotificationAttachment(identifier: fileName, url: fileURL, options: nil)
            Logger.common(message: "[SchedulingPush]: Successfully saved image with name: \(fileName), to url: \(fileURL)", category: .notification)
            return attachment
        } catch {
            Logger.common(message: "[SchedulingPush]: Failed to save image or create attachment. Error: \(error.localizedDescription)",
                          level: .error, category: .notification)
            return nil
        }
    }
}

// MARK: - Save Push for Notification Center to SwiftData

private extension NotificationService {

    @MainActor
    func saveSwiftDataItem(_ mindboxPushNotification: MBPushNotification) async {
        let context = SwiftDataManager.shared.container.mainContext

        let push = PushNotification(title: mindboxPushNotification.aps?.alert?.title,
                                    body: mindboxPushNotification.aps?.alert?.body,
                                    clickUrl: mindboxPushNotification.clickUrl,
                                    imageUrl: mindboxPushNotification.imageUrl,
                                    payload: mindboxPushNotification.payload,
                                    uniqueKey: mindboxPushNotification.uniqueKey)
        let newItem = Item(timestamp: Date(), pushNotification: push)

        context.insert(newItem)
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}
