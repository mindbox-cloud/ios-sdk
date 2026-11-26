//
//  ClientGateClickReporter.swift
//  Example
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import os

struct ClientGateClick: Encodable {
    let messageId: String
    let clickKey: String?
    let occurredAtUtc: String

    init?(response: UNNotificationResponse, occurredAt: Date = Date()) {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              let messageId = response.notification.request.content.userInfo["uniqueKey"] as? String,
              !messageId.isEmpty else {
            return nil
        }
        self.messageId = messageId
        clickKey = response.actionIdentifier == UNNotificationDefaultActionIdentifier ? nil : response.actionIdentifier
        occurredAtUtc = Self.dateFormatter.string(from: occurredAt)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

final class ClientGateClickReporter {

    static let shared = ClientGateClickReporter()

    private let maxAttempts = 3
    private let session: URLSession
    private let logger = Logger(subsystem: "cloud.Mindbox.Example", category: "ClientGateClick")

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        session = URLSession(configuration: configuration)
    }

    func report(_ click: ClientGateClick) {
        guard let request = makeRequest(for: click) else {
            return
        }

        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        let endBackgroundTask = {
            guard backgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ClientGateClick") { [logger] in
            logger.error("Background time expired, click \(click.messageId, privacy: .public) may be lost")
            endBackgroundTask()
        }

        send(request, click: click, attempt: 1) {
            DispatchQueue.main.async(execute: endBackgroundTask)
        }
    }

    private func makeRequest(for click: ClientGateClick) -> URLRequest? {
        let clickURL = infoPlistString(for: "ClientGateClickURL")
        let token = infoPlistString(for: "ClientGateToken")
        guard !clickURL.isEmpty, !token.isEmpty else {
            logger.error("ClientGateClickURL or ClientGateToken is empty in Info.plist, click \(click.messageId, privacy: .public) is not sent")
            return nil
        }
        guard let url = URL(string: clickURL), url.scheme?.lowercased() == "https" else {
            logger.error("ClientGateClickURL must be an https URL, click \(click.messageId, privacy: .public) is not sent")
            return nil
        }
        guard let body = try? JSONEncoder().encode(click) else {
            logger.error("Failed to encode click \(click.messageId, privacy: .public)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest, click: ClientGateClick, attempt: Int, completion: @escaping () -> Void) {
        session.dataTask(with: request) { [self] _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let attemptInfo = "attempt \(attempt)/\(maxAttempts)"

            switch statusCode {
            case .some(200..<300):
                logger.info("Click \(click.messageId, privacy: .public) sent, clickKey \(click.clickKey ?? "none", privacy: .public), HTTP \(statusCode ?? 0), \(attemptInfo, privacy: .public)")
                completion()
            case .some(401):
                logger.error("Client gate answered 401 for click \(click.messageId, privacy: .public): ClientGateToken is expired or invalid")
                showUnauthorizedAlert()
                completion()
            case .some(500..<600), .none:
                let reason = error?.localizedDescription ?? "HTTP \(statusCode ?? 0)"
                guard attempt < maxAttempts else {
                    logger.error("Click \(click.messageId, privacy: .public) is lost after \(attemptInfo, privacy: .public): \(reason, privacy: .public)")
                    completion()
                    return
                }
                logger.error("Click \(click.messageId, privacy: .public) failed, \(attemptInfo, privacy: .public), retrying: \(reason, privacy: .public)")
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(attempt)) {
                    self.send(request, click: click, attempt: attempt + 1, completion: completion)
                }
            case .some(let code):
                logger.error("Client gate rejected click \(click.messageId, privacy: .public) with HTTP \(code)")
                completion()
            }
        }.resume()
    }

    private func showUnauthorizedAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Client gate: HTTP 401",
                message: "The click was not accepted: ClientGateToken is expired or invalid. Put a new token into Info.plist and rebuild the app.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            Self.topViewController()?.present(alert, animated: true)
        }
    }

    private func infoPlistString(for key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var topViewController = keyWindow?.rootViewController
        while let presented = topViewController?.presentedViewController {
            topViewController = presented
        }
        return topViewController
    }
}
