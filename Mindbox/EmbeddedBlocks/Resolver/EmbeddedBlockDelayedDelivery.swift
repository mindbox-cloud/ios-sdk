//
//  EmbeddedBlockDelayedDelivery.swift
//  Mindbox
//
//  Created by Sergei Semko on 25.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What a held answer waits out its delay for: one in-app, in one session.
struct EmbeddedBlockDelayedWinner: Equatable {
    let inappId: String
    let sessionEpoch: Int
}

/// Holds a place's answer for its `delayTime`, like the schedule queue holds an overlay: the newest replaces the waiting one,
/// and what runs out while the user is not present is delivered once they are. Main thread only.
final class EmbeddedBlockDelayedDelivery<Answer>: EmbeddedBlockAppPresenceSubscribing {

    typealias Delivery = (Answer) -> Void

    private struct Waiting {
        let winner: EmbeddedBlockDelayedWinner
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
    private let presence: EmbeddedBlockAppPresence

    init(presence: EmbeddedBlockAppPresence = .shared,
         schedule: @escaping EmbeddedBlockWaitScheduling = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.presence = presence
        self.schedule = schedule

        presence.subscribe(self)
    }

    deinit {
        for entry in waiting.values {
            if case .ticking(let timer) = entry.state {
                timer.cancel()
            }
        }
    }

    func userDidBecomePresent() {
        deliverDue()
    }

    func isWaiting(place: String, for winner: EmbeddedBlockDelayedWinner) -> Bool {
        waiting[place]?.winner == winner
    }

    func schedule(place: String, winner: EmbeddedBlockDelayedWinner, answer: Answer, after delay: TimeInterval, _ deliver: @escaping Delivery) {
        cancel(place: place)

        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.isWaiting(place: place, for: winner) else { return }

            if self.presence.isPresent {
                self.deliver(place)
            } else {
                self.waiting[place]?.state = .due
            }
        }

        waiting[place] = Waiting(winner: winner, answer: answer, deliver: deliver, state: .ticking(timer))
        schedule(delay, timer)
    }

    /// The newest answer of the same session for the in-app already waiting at the place; its delay keeps running.
    func refresh(place: String, answer: Answer) {
        waiting[place]?.answer = answer
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
