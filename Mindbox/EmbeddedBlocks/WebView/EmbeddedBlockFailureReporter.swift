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

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': reporting \(failure.reason.rawValue) for in-app \(failure.inAppId)",
                      level: .error, category: .embeddedBlocks)
        report(failure.inAppId, failure.tags, failure.reason, failure.details)
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

    func reportUnansweredWaitOnce(_ waited: TimeInterval) {
        guard SessionTemporaryStorage.shared.$ledger.mutate({ $0.recordUnanswered(placeSystemName) }) else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK stayed silent again this session — already reported",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the SDK never answered within \(waited.toTimeSpan()) — reporting a failure without an in-app",
                      level: .error, category: .embeddedBlocks)
        reportUnansweredWait(waited)
    }
}
