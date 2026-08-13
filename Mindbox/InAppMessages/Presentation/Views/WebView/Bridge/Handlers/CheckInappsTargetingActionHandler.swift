//
//  CheckInappsTargetingActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Answers which of the in-apps the page asked about currently pass targeting.
///
/// **Not implemented yet: every id is let through.** The page can therefore render its whole
/// feed, which is what makes the rest of the contract testable, but nothing here is filtering
/// anything.
final class CheckInappsTargetingActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.checkInappsTargeting]

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard case .array(let requested)? = message.payloadObject?["inappIds"] else {
            host.respondError("Invalid payload: missing 'inappIds' array", to: message)
            return
        }

        let ids = requested.compactMap { value -> String? in
            guard case .string(let id) = value else { return nil }
            return id
        }

        // TODO: Answer from the targeting the SDK has already computed, without touching the
        // network — the page gives up after three seconds and renders nothing rather than wait.
        //   - the ids are looked up in `inappFilterService.validInapps`;
        //   - `targetingChecker.check(targeting:)` is synchronous and does no I/O: it reads
        //     `checkedSegmentations` / `geoModels` that a previous pass already warmed;
        //   - a cold cache answers false, which is a feed that renders nothing. That is accepted
        //     rather than waited out, but it deserves a log of its own — silence here is
        //     indistinguishable from "nothing passed";
        //   - an id absent from the config is excluded rather than let through, and named in the
        //     log: "why is my story missing" is the first question this will be asked;
        //   - ORDER MATTERS: the page maps the answer back onto its own cards.
        //   - THREAD SAFETY: `checkedSegmentations` is written from `InappMapper`'s queue, and
        //     this would be the first main-thread reader. Settle that together with the logic.
        Logger.common(message: "[WebView] checkInappsTargeting is not implemented: letting all \(ids.count) id(s) through",
                      level: .default,
                      category: host.logCategory)

        host.respond(to: message, payload: .object(["inappIds": .array(ids.map { .string($0) })]))
    }
}
