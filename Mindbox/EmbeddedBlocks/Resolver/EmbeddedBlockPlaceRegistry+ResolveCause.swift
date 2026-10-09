//
//  EmbeddedBlockPlaceRegistry+ResolveCause.swift
//  Mindbox
//
//  Created by Sergei Semko on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension EmbeddedBlockPlaceRegistry {

    struct QueuedInvalidation {
        var trigger: ApplicationEvent?
        var includesNonOperation: Bool
        /// The new session's re-ask that waited behind a pass in flight: its show is timed from here.
        var newSessionAskedAt: TimeInterval?
        var isAskedOffScreen = false
    }

    enum ResolveCause {
        case blockAppeared
        case newConfig
        case newSession
        case operation(ApplicationEvent)
        case queued(QueuedInvalidation)

        var trigger: ApplicationEvent? {
            switch self {
                case .blockAppeared, .newConfig, .newSession: return nil
                case .operation(let event): return event
                case .queued(let queued): return queued.trigger
            }
        }

        /// A pass that also answers a config, a session or an appearance is not an operation's, whatever
        /// operation it carries.
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

        var wasQueuedOffScreen: Bool {
            guard case .queued(let queued) = self else { return false }

            return queued.isAskedOffScreen
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
                case .newSession: return "a new session"
                case .operation(let event): return "operation '\(event.name)'"
                case .queued: return "a queued invalidation"
            }
        }
    }
}
