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
    /// `actions`.
    ///
    /// An action that is `isDeferred` must answer exactly once through `host`. One that is not
    /// must not answer at all: `RequestMessageHandler` has already sent `{success: true}` for it,
    /// and a second answer would arrive against an id JS has closed.
    func handle(_ message: BridgeMessage, host: WebBridgeHost)

    /// The session is over — the page is going away, or it asked to be closed. Whatever holds
    /// the device (haptic engine, motion sensors) is released here.
    func tearDown()
}

extension WebBridgeActionHandler {

    /// Most handlers hold nothing that outlives a request.
    func tearDown() {}
}

/// Routes a bridge request to whoever owns its action.
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

    /// - Returns: `false` when no handler owns the action. Not an error in itself — the web
    ///   vocabulary is allowed to be newer than the SDK — so how loudly to report it is the
    ///   caller's call. Anything that is not a request is reported as handled: it was never a
    ///   handler's to answer.
    @discardableResult
    func handle(_ message: BridgeMessage, host: WebBridgeHost) -> Bool {
        // Handlers are promised requests only, and it is this door that has to keep the promise:
        // a host forwards everything the dispatcher matched, confirmed responses to what we sent
        // the page included. A confirmed `motion.event` is not an unknown action — it is not an
        // action at all — so it is swallowed here rather than reported to the host as one.
        guard message.type == .request else { return true }

        guard let action = message.parsedAction, let owner = owners[action] else {
            return false
        }

        // The one door for `requiresUserPresence`: a handler that never runs cannot act on a page
        // nobody is looking at, whatever it was going to do. A refusal still counts as handled —
        // the action is owned, and reporting it as unknown would send the caller looking for a
        // missing handler.
        guard !action.requiresUserPresence || host.requireUserPresence(for: message) else {
            return true
        }

        owner.handle(message, host: host)
        return true
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
