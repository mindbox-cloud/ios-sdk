//
//  WebBridgeActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// One bridge action, or a family of them, handled apart from the view it arrived in.
///
/// Handlers know nothing about which page is talking to them: everything they may need comes
/// through the `WebBridgeHost` handed to `handle`. That is what lets one set of them serve
/// every WebView the SDK shows.
protocol WebBridgeActionHandler: AnyObject {

    /// The actions this handler owns. Fixed for the life of the instance — the registry indexes
    /// it once, so dispatch is a lookup rather than a walk down a list.
    var actions: Set<BridgeMessage.Action> { get }

    /// Main thread. `message.type` is always `.request`, and its action is always one of
    /// `actions`. Answers exactly once through `host`, unless it hands the question on to a host
    /// that drops it (see ``WebBridgeInappRequestHosting``).
    func handle(_ message: BridgeMessage, host: WebBridgeHost)

    /// The session is over — the page is going away, or it asked to be closed. Whatever holds
    /// the device (haptic engine, motion sensors) is released here.
    func tearDown()
}

extension WebBridgeActionHandler {

    /// Most handlers hold nothing that outlives a request.
    func tearDown() {}
}

/// Routes a bridge request to whoever owns its action, and refuses one nobody owns.
///
/// One registry per bridge session, built from handler instances of that same session: several
/// handlers keep state that belongs to one page — a prepared haptic engine, a motion
/// subscription — and it has to die with that page, not with the process.
final class WebBridgeActionRegistry {

    private let handlers: [WebBridgeActionHandler]

    private var owners: [BridgeMessage.Action: WebBridgeActionHandler] = [:]

    init(handlers: [WebBridgeActionHandler]) {
        self.handlers = handlers

        for handler in handlers {
            for action in handler.actions {
                guard owners[action] == nil else {
                    // Two handlers claiming one action is a wiring mistake, not a runtime
                    // condition: keep the first so behaviour stays deterministic, and say it
                    // loudly enough to be found before release.
                    Logger.common(message: "[WebView] Bridge: action '\(action.rawValue)' is claimed by more than one handler, keeping the first",
                                  level: .error,
                                  category: .webViewInAppMessages)
                    continue
                }

                owners[action] = handler
            }
        }
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard message.type == .request else { return }

        guard let action = message.parsedAction else { return }

        guard let owner = owners[action] else {
            host.respondError(.notServed, detail: "no handler owns this action", to: message)
            return
        }

        // The one door for `requiresUserPresence`: a handler that never runs cannot act on a page
        // nobody is looking at, whatever it was going to do.
        guard !action.requiresUserPresence || host.requireUserPresence(for: message) else {
            return
        }

        owner.handle(message, host: host)
    }

    func tearDown() {
        handlers.forEach { $0.tearDown() }
    }

    /// The one door for a caller that must reach a handler outside a request: a system shake
    /// arrives at the view, not at the bridge.
    func handler<T: WebBridgeActionHandler>(ofType type: T.Type) -> T? {
        handlers.first { $0 is T } as? T
    }
}
