//
//  PasteboardUUIDDebugService.swift
//  Mindbox
//
//  Created by Aleksandr Svetilov on 02.08.2022.
//

import Foundation
import UIKit

internal final class PasteboardUUIDDebugService: UUIDDebugService {

    static let triggerNotificationName = UIApplication.didBecomeActiveNotification
    static let triggerNotificationCount = 5
    static let triggerNotificationInterval: TimeInterval = 2

    private let notificationCenter: NotificationCenter
    private let currentDateProvider: () -> Date
    private let pasteboard: UIPasteboard
    private var uuid: String?

    private var lastReceivedDate: Date?
    private var notificationCount = 0

    private var started = false

    init(
        notificationCenter: NotificationCenter,
        currentDateProvider: @escaping () -> Date,
        pasteboard: UIPasteboard
    ) {
        self.notificationCenter = notificationCenter
        self.currentDateProvider = currentDateProvider
        self.pasteboard = pasteboard
    }

    func start(with uuid: String) {
        if started { return }

        self.uuid = uuid
        notificationCenter.addObserver(
            self,
            selector: #selector(didReceiveNotification),
            name: Self.triggerNotificationName,
            object: nil
        )

        started = true
    }

    @objc
    private func didReceiveNotification() {
        let now = currentDateProvider()

        if now.timeIntervalSince(lastReceivedDate ?? now) < Self.triggerNotificationInterval {
            notificationCount += 1
        } else {
            notificationCount = 1
        }

        if notificationCount > Self.triggerNotificationCount - 1 {
            notificationCount = 0
            copyUUIDToPasteboard()
        }

        lastReceivedDate = now
    }

    private func copyUUIDToPasteboard() {
        guard let id = uuid else { return }

        pasteboard.string = id
    }
}
