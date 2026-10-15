//
//  EmbeddedBlockPlaceRegistry+SessionCheck.swift
//  Mindbox
//
//  Created by Sergei Semko on 15.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension EmbeddedBlockPlaceRegistry {

    struct AwaitingTheSessionCheck {

        typealias Kept = (answer: EmbeddedBlockPlaceAnswer, keptAt: TimeInterval)

        var content: [String: Kept] = [:]

        var operations: [String: ApplicationEvent] = [:]

        mutating func keep(_ answer: EmbeddedBlockPlaceAnswer, at place: String, now: () -> TimeInterval) {
            if let kept = content[place], kept.answer.sessionEpoch == answer.sessionEpoch,
               kept.answer.resolution.content?.inAppId == answer.resolution.content?.inAppId {
                content[place] = (answer.replacing(kept.answer), kept.keptAt)
            } else {
                content[place] = (answer, now())
            }
        }

        mutating func takeOperations() -> [String: ApplicationEvent] {
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
