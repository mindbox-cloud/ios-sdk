//
//  EmbeddedBlockResolution+Collapse.swift
//  Mindbox
//
//  Created by Sergei Semko on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension EmbeddedBlockResolution {

    /// The state an answer without content leaves its block in, and why, for the log; `nil` for content.
    var collapse: (state: EmbeddedBlockState, reason: String)? {
        switch self {
        case .content:
            return nil
        case .empty:
            return (.empty, "nothing at this place — collapsing")
        case .failure(let failure):
            return (.failed(MindboxEmbeddedBlockFailReason(failure.reason)), "\(failure.details) — failing")
        case .configUnavailable:
            return (.failed(MindboxEmbeddedBlockFailReason(.waitBudgetExceeded)), "the SDK has no config to answer with — failing")
        case .targetingUnavailable:
            return (.failed(.networkError), "the place could not be checked — failing")
        }
    }
}
