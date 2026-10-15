//
//  EmbeddedBlockPlaceRegistry+SessionCheck.swift
//  Mindbox
//
//  Created by Sergei Semko on 15.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

extension EmbeddedBlockPlaceRegistry {

    struct AwaitingTheSessionCheck {

        typealias Kept = (answer: EmbeddedBlockPlaceAnswer, keptAt: TimeInterval)

        var content: [String: Kept] = [:]

        private var operations: [String: [ResolveCause]] = [:]

        mutating func hold(_ operation: ApplicationEvent, at place: String) {
            operations[place, default: []].append(.operation(operation))
        }

        mutating func merge(_ cause: ResolveCause, intoTheFirstHeldOperationAt place: String) -> Bool {
            guard cause.joinsHeldOperations, let first = operations[place]?.first else { return false }

            Logger.common(message: "[EmbeddedBlock] Place '\(place)': \(cause.logDescription) while operations for it wait for the return's session check — asked with the first of them",
                          category: .embeddedBlocks)
            operations[place]?[0] = .queued(QueuedInvalidation(trigger: first.trigger, includesNonOperation: true))
            return true
        }

        mutating func keep(_ answer: EmbeddedBlockPlaceAnswer, at place: String, now: () -> TimeInterval) {
            if let kept = content[place], kept.answer.sessionEpoch == answer.sessionEpoch,
               kept.answer.resolution.content?.inAppId == answer.resolution.content?.inAppId {
                content[place] = (answer.replacing(kept.answer), kept.keptAt)
            } else {
                content[place] = (answer, now())
            }
        }

        mutating func takeOperations() -> [String: [ResolveCause]] {
            let taken = operations
            operations = [:]
            return taken
        }

        mutating func takeContentInKeptOrder() -> [(key: String, value: Kept)] {
            let kept = content
            content = [:]
            return kept.sorted { ($0.value.keptAt, $0.key) < ($1.value.keptAt, $1.key) }
        }
    }
}
