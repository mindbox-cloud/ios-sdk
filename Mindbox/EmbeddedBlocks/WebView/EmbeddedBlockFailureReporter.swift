//
//  EmbeddedBlockFailureReporter.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class EmbeddedBlockFailureReporter {

    typealias Report = (_ inAppId: String, _ tags: [String: String]?, _ reason: InAppShowFailureReason, _ details: String) -> Void

    private let placeSystemName: String

    private let report: Report

    private let reportUnansweredWait: (_ waited: TimeInterval) -> Void

    private var held: EmbeddedBlockResolutionFailure?

    init(placeSystemName: String,
         report: @escaping Report,
         reportUnansweredWait: @escaping (_ waited: TimeInterval) -> Void) {
        self.placeSystemName = placeSystemName
        self.report = report
        self.reportUnansweredWait = reportUnansweredWait
    }

    func report(_ failure: EmbeddedBlockResolutionFailure, isBlockOnScreen: Bool) {
        guard isBlockOnScreen else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': \(failure.reason.rawValue) for in-app \(failure.inAppId) happened off screen — held until the block is looked at",
                          category: .embeddedBlocks)
            held = failure
            return
        }

        send(failure)
    }

    /// What an answer without content tells the analytics when it arrives, held or parked, as on Android: only
    /// the state it moves the block to waits, and a teardown before that loses nothing.
    func report(failureOf answer: EmbeddedBlockPlaceAnswer) {
        switch answer.resolution {
        case .failure(let failure):
            send(failure)
        case .configUnavailable:
            reportUnansweredWaitOnce(answer.processingDuration, inSession: answer.sessionEpoch)
        case .content, .empty, .targetingUnavailable:
            break
        }
    }

    func flushHeld() {
        guard let held = held else { return }

        self.held = nil

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': reporting the held \(held.reason.rawValue) for in-app \(held.inAppId)",
                      level: .error, category: .embeddedBlocks)
        report(held.inAppId, held.tags, held.reason, held.details)
    }

    func discardHeld() {
        held = nil
    }

    private func send(_ failure: EmbeddedBlockResolutionFailure) {
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': reporting \(failure.reason.rawValue) for in-app \(failure.inAppId)",
                      level: .error, category: .embeddedBlocks)
        report(failure.inAppId, failure.tags, failure.reason, failure.details)
    }

    /// `sessionEpoch`: the session of the answer that says so — one of a session that has ended reports nothing.
    func reportUnansweredWaitOnce(_ waited: TimeInterval, inSession sessionEpoch: Int? = nil) {
        let isFirst = SessionTemporaryStorage.shared.$ledger.mutate { ledger -> Bool? in
            if let sessionEpoch, ledger.hasEnded(sessionEpoch) {
                return nil
            }

            return ledger.recordUnanswered(placeSystemName)
        }

        guard let isFirst else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': no config to answer with in a session that has ended — not reported",
                          category: .embeddedBlocks)
            return
        }

        guard isFirst else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK stayed silent again this session — already reported",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK never answered within \(waited.toTimeSpan()) — reporting a failure without an in-app",
                      level: .error, category: .embeddedBlocks)
        reportUnansweredWait(waited)
    }
}
