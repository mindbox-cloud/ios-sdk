//
//  EmbeddedBlockDelayedDelivery.swift
//  Mindbox
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// Holds a place's answer for its `delayTime`, like the schedule queue holds an overlay: one answer per
/// place, the caller refreshes the waiting one through `refresh(place:_:)` while its delay keeps
/// running, nothing is delivered in the background. Main thread only.
final class EmbeddedBlockDelayedDelivery<Answer> {

    typealias Delivery = (Answer) -> Void

    private struct Waiting {
        let inappId: String
        var answer: Answer
        let deliver: Delivery
        var state: State
    }

    private enum State {
        case ticking(DispatchWorkItem)
        case due
    }

    private var waiting: [String: Waiting] = [:]

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
        for entry in waiting.values {
            if case .ticking(let timer) = entry.state {
                timer.cancel()
            }
        }
    }

    func isWaiting(place: String, for inappId: String) -> Bool {
        waiting[place]?.inappId == inappId
    }

    func waitingAnswer(at place: String) -> Answer? {
        waiting[place]?.answer
    }

    func schedule(place: String, inappId: String, answer: Answer, after delay: TimeInterval, _ deliver: @escaping Delivery) {
        cancel(place: place)

        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.waiting[place]?.inappId == inappId else { return }

            if self.isInBackground() {
                self.waiting[place]?.state = .due
            } else {
                self.deliver(place)
            }
        }

        waiting[place] = Waiting(inappId: inappId, answer: answer, deliver: deliver, state: .ticking(timer))
        schedule(delay, timer)
    }

    /// Updates the answer of the in-app already waiting at the place; its delay keeps running.
    func refresh(place: String, _ update: (Answer) -> Answer) {
        guard let current = waiting[place]?.answer else { return }

        waiting[place]?.answer = update(current)
    }

    func cancel(place: String) {
        stopTicking(place)
        waiting[place] = nil
    }

    private func stopTicking(_ place: String) {
        if case .ticking(let timer)? = waiting[place]?.state {
            timer.cancel()
        }
    }

    private func deliverDue() {
        let due = waiting.compactMap { place, entry -> String? in
            if case .due = entry.state { return place }
            return nil
        }
        due.forEach(deliver)
    }

    private func deliver(_ place: String) {
        guard let entry = waiting.removeValue(forKey: place) else { return }
        entry.deliver(entry.answer)
    }
}
