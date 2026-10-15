//
//  EmbeddedBlockPlaceRegistry+ResolveCause.swift
//  Mindbox
//
//  Created by Sergei Semko on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

protocol EmbeddedBlockAskedPass {
    var askedInSession: Int { get }
    var isTriggered: Bool { get }
}

extension EmbeddedBlockAskedPass {

    func isOperationFreeAsk(of sessionEpoch: Int) -> Bool {
        askedInSession == sessionEpoch && !isTriggered
    }
}

extension EmbeddedBlockPlaceRegistry {

    struct QueuedInvalidation {
        var trigger: ApplicationEvent?
        var includesNonOperation: Bool
        var newSessionAskedAt: TimeInterval?
    }

    final class PassInFlight: EmbeddedBlockAskedPass {
        let askedInSession: Int
        let isTriggered: Bool
        var isAskedAgainMidResolve = false
        var isConfigAnnouncedMidResolve = false

        init(askedInSession: Int, isTriggered: Bool) {
            self.askedInSession = askedInSession
            self.isTriggered = isTriggered
        }

        func answered(from configVersion: ConfigVersion?) -> AnsweredPass {
            AnsweredPass(askedInSession: askedInSession, isTriggered: isTriggered, configVersion: configVersion)
        }

        func isAnsweredFromConfig(_ configVersion: ConfigVersion?, olderThan newest: ConfigVersion?) -> Bool {
            guard isConfigAnnouncedMidResolve, let newest else { return false }

            return configVersion.map { $0 < newest } ?? true
        }
    }

    struct AnsweredPass: EmbeddedBlockAskedPass {
        let askedInSession: Int
        let isTriggered: Bool
        let configVersion: ConfigVersion?
    }

    enum ResolveCause {
        case blockAppeared
        case newConfig
        case newSession(ApplicationEvent?)
        case operation(ApplicationEvent)
        case queued(QueuedInvalidation)

        var trigger: ApplicationEvent? {
            switch self {
                case .blockAppeared, .newConfig: return nil
                case .newSession(let event): return event
                case .operation(let event): return event
                case .queued(let queued): return queued.trigger
            }
        }

        var includesNonOperation: Bool {
            switch self {
                case .blockAppeared, .newConfig, .newSession: return true
                case .queued(let queued): return queued.includesNonOperation
                case .operation: return false
            }
        }

        var newSessionAskedAt: TimeInterval? {
            guard case .queued(let queued) = self else { return nil }

            return queued.newSessionAskedAt
        }

        var isNewSessionAsk: Bool {
            if case .newSession = self {
                return true
            }

            return newSessionAskedAt != nil
        }

        var queuesWhenBusy: Bool {
            if case .blockAppeared = self {
                return false
            }

            return true
        }

        var logDescription: String {
            switch self {
                case .blockAppeared: return "the block appeared"
                case .newConfig: return "a new config"
                case .newSession(let event): return event.map { "a new session, with operation '\($0.name)'" } ?? "a new session"
                case .operation(let event): return "operation '\(event.name)'"
                case .queued: return "a queued invalidation"
            }
        }
    }
}

extension EmbeddedBlockPlaceRegistry.QueuedInvalidation {

    init(merging cause: EmbeddedBlockPlaceRegistry.ResolveCause, into queued: Self?, now: () -> TimeInterval) {
        let newSessionAskedAt: TimeInterval?
        if case .newSession = cause {
            newSessionAskedAt = now()
        } else {
            newSessionAskedAt = cause.newSessionAskedAt
        }
        self.init(trigger: cause.trigger ?? queued?.trigger,
                  includesNonOperation: cause.includesNonOperation || queued?.includesNonOperation == true,
                  newSessionAskedAt: [queued?.newSessionAskedAt, newSessionAskedAt].compactMap { $0 }.min())
    }
}
