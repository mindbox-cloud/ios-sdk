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
    }

    enum ResolveCause {
        case blockAppeared
        case newConfig
        case operation(ApplicationEvent)
        case queued(QueuedInvalidation)

        var trigger: ApplicationEvent? {
            switch self {
                case .blockAppeared, .newConfig: return nil
                case .operation(let event): return event
                case .queued(let queued): return queued.trigger
            }
        }

        var includesNonOperation: Bool {
            switch self {
                case .blockAppeared, .newConfig: return true
                case .queued(let queued): return queued.includesNonOperation
                case .operation: return false
            }
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
                case .operation(let event): return "operation '\(event.name)'"
                case .queued: return "a queued invalidation"
            }
        }
    }
}
