//
//  NotificationService.swift
//  MindboxNotifications
//
//  Created by Sergei Semko on 8/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

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
    /// It tells Mindbox that the push reached the device, without waiting for the answer.
    /// To have the answer before the push is shown, use `confirmDelivery(_:)` of `MindboxNotificationService` instead.
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

        // The image loads while the confirmation waits for its answer; the push is shown after both.
        let confirming = startConfirmation(of: request)
        let finish: () -> Void = { [weak self] in
            guard let confirming else {
                self?.proceedFinalStage(bestAttemptContent)
                return
            }
            Task { [weak self] in
                await confirming.value
                self?.proceedFinalStage(bestAttemptContent)
            }
        }

        if let imageUrl = parse(request: request)?.withImageURL?.imageUrl,
           let allowedUrl = imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: allowedUrl) {
            downloadImage(with: url, completion: finish)
        } else {
            finish()
        }
    }

    /// Call this method in `serviceExtensionTimeWillExpire()` of `NotificationService`
    public func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent = bestAttemptContent {
            proceedFinalStage(bestAttemptContent)
        }
    }

    /// Call this method in `didReceive(_ request, withContentHandler)` of your `NotificationService` if you have implemented a custom version of NotificationService.
    /// It tells Mindbox that the push reached the device, without waiting for the answer.
    /// To have the answer before the push is shown, use `confirmDelivery(_:)` instead.
    public func pushDelivered(_ request: UNNotificationRequest) {
        let message = "[NotificationService] \(#function), request id: \(request.identifier)"
        print(message)
        startConfirmation(of: request)
    }

    /// Tells Mindbox that the push reached the device and returns when Mindbox answers, in 5 seconds at most.
    ///
    /// Call it in `didReceive(_ request, withContentHandler)` of your `NotificationService` before you pass the content
    /// to `contentHandler`, instead of `pushDelivered(_:)`:
    ///
    /// ```swift
    /// override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    ///     Task {
    ///         await mindboxService.confirmDelivery(request)
    ///         contentHandler(bestAttemptContent ?? request.content)
    ///     }
    /// }
    /// ```
    ///
    /// The system may stop the extension soon after the push is shown, so a confirmation sent without waiting can be lost.
    /// When Mindbox does not answer in time, the app sends the confirmation again on its next start or return to the foreground.
    /// A push that does not ask for a confirmation returns at once.
    public func confirmDelivery(_ request: UNNotificationRequest) async {
        await startConfirmation(of: request)?.value
    }
}

// MARK: Private methods for MindboxNotificationServiceProtocol

private extension MindboxNotificationService {

    /// - Returns: The running confirmation, or `nil` when the push does not ask for one.
    @discardableResult
    func startConfirmation(of request: UNNotificationRequest) -> Task<Void, Never>? {
        guard let confirmation = PushDeliveryConfirmation(userInfo: request.content.userInfo) else {
            return nil
        }
        return deliveryConfirmer.start(confirmation)
    }

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
