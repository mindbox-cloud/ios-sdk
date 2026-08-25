//
//  EmbeddedBlockDelayedDelivery.swift
//  Mindbox
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// Holds a place's answer for its `delayTime`, the way the schedule queue holds an overlay: one answer
/// per place, the newest replaces the one waiting, and nothing is delivered in the background — a delay
/// that runs out there is delivered when the app comes back.
///
/// Called on the main thread, like the registry that owns it.
final class EmbeddedBlockDelayedDelivery {

    typealias Delivery = () -> Void

    private struct Waiting {
        let inappId: String
        let work: DispatchWorkItem
    }

    private var waiting: [String: Waiting] = [:]

    private var due: [String: Delivery] = [:]

    private let schedule: EmbeddedBlockWaitScheduling
    private let isInBackground: () -> Bool
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    init(isInBackground: @escaping () -> Bool = { UIApplication.shared.applicationState == .background },
         notificationCenter: NotificationCenter = .default,
         schedule: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.isInBackground = isInBackground
        self.notificationCenter = notificationCenter
        self.schedule = schedule

        observer = notificationCenter.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                  object: nil,
                                                  queue: .main) { [weak self] _ in
            self?.deliverDue()
        }
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
        waiting.values.forEach { $0.work.cancel() }
    }

    func isWaiting(place: String, for inappId: String) -> Bool {
        waiting[place]?.inappId == inappId
    }

    func schedule(place: String, inappId: String, after delay: TimeInterval, _ deliver: @escaping Delivery) {
        cancel(place: place)

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.waiting[place]?.inappId == inappId else { return }

            self.waiting[place] = nil

            if self.isInBackground() {
                self.due[place] = deliver
            } else {
                deliver()
            }
        }

        waiting[place] = Waiting(inappId: inappId, work: work)
        schedule(delay, work)
    }

    func cancel(place: String) {
        waiting[place]?.work.cancel()
        waiting[place] = nil
        due[place] = nil
    }

    private func deliverDue() {
        let deliveries = due
        due = [:]
        deliveries.values.forEach { $0() }
    }
}
