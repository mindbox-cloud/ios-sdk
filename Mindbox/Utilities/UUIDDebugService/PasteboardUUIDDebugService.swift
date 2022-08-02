//
//  PasteboardUUIDDebugService.swift
//  Mindbox
//
//  Created by Aleksandr Svetilov on 02.08.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

internal final class PasteboardUUIDDebugService: UUIDDebugService {

    private let notificationCenter: NotificationCenter
    private let currentDateProvider: () -> Date
    private let pasteboard: UIPasteboard
    private var uuid: String?

    private var lastReceivedDate: Date?
    private var notificationCount = 0

    internal init(
        notificationCenter: NotificationCenter,
        currentDateProvider: @escaping () -> Date,
        pasteboard: UIPasteboard
    ) {
        self.notificationCenter = notificationCenter
        self.currentDateProvider = currentDateProvider
        self.pasteboard = pasteboard
    }

    internal func start(with uuid: String) {
        self.uuid = uuid
        notificationCenter.addObserver(
            self,
            selector: #selector(didReceiveNotification),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func didReceiveNotification() {
        let now = currentDateProvider()

        if let lastReceived = lastReceivedDate,
           now.timeIntervalSince(lastReceived) < 2
        {
            notificationCount += 1
        } else {
            notificationCount = 1
        }

        if notificationCount > 4 {
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
