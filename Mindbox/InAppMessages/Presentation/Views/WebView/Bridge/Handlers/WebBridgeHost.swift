//
//  WebBridgeHost.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// The WebView an action runs in, as much of it as a handler is allowed to know.
///
/// Deliberately narrow. A handler that needs more than this is not a shared handler: it wants
/// something only one kind of page can do, and that belongs behind a capability protocol below
/// rather than behind a check of which surface we are on.
protocol WebBridgeHost: AnyObject {

    /// The in-app id for a popup, the block id for an embedded block. Goes into the logs, and
    /// into the start payload as `inAppId`.
    var contentId: String { get }

    /// Where this host journals. Each surface keeps its own trail, so a handler shared by all
    /// of them has to ask instead of hardcoding a category.
    var logCategory: LogCategory { get }

    /// In-app tags, merged into operation bodies. Absent on pages that have none.
    var tags: [String: String]? { get }

    /// What a handler presents from when it needs a controller of its own (`SFSafariViewController`).
    /// `nil` means the handler falls back to the key window.
    var presentingViewController: UIViewController? { get }

    /// Whether a user is looking at this page right now.
    ///
    /// An embedded block that left the window keeps its page alive, and that page still
    /// delivers whatever its `setTimeout` scheduled. Not a single touch stands behind such a
    /// message, so anything acting on the user's behalf — opening a link, showing a window —
    /// must not run on it.
    var isUserPresent: Bool { get }

    /// Native → JS. The only way out of a handler.
    func send(_ message: BridgeMessage)

    /// The parameters this page needs to configure itself.
    ///
    /// Built by the host rather than by the handler: what goes in depends on what the page is —
    /// an in-app knows its operation, a block knows its configuration entry — while answering
    /// `ready` with it is the same everywhere. Snapshot at the moment of asking, so a page that
    /// asks again is told what is true now.
    func makeStartPayload() -> JSONValue
}

// MARK: - Answering a request

/// The three ways to answer.
///
/// They take the request itself rather than an id and an action, so a response cannot drift
/// from what it answers — the mismatch is not expressible.
extension WebBridgeHost {

    func respond(to message: BridgeMessage, payload: JSONValue) {
        send(BridgeMessage(type: .response, action: message.action, payload: payload, id: message.id))
    }

    func respondSuccess(to message: BridgeMessage) {
        respond(to: message, payload: .object(["success": .bool(true)]))
    }

    func respondError(_ reason: String, to message: BridgeMessage) {
        Logger.common(message: "[WebView] Bridge: '\(message.action)' failed for '\(contentId)': \(reason)",
                      level: .error,
                      category: logCategory)

        send(BridgeMessage(type: .error,
                           action: message.action,
                           payload: .object(["error": .string(reason)]),
                           id: message.id))
    }
}

// MARK: - Acting on the user's behalf

extension WebBridgeHost {

    /// Whether a request that acts on the user's behalf may go ahead here and now.
    ///
    /// Asked in two places, and both are needed. ``WebBridgeActionRegistry`` asks before it
    /// dispatches, which stops the whole class of such actions at one door. A handler that then
    /// goes on to wait — on the system, on a dialog the user is free to leave standing — asks
    /// again when it comes back, because the page can leave the screen while it waits and the
    /// answer would otherwise land as a Safari sheet over a screen the user went to on their own.
    ///
    /// - Returns: `true` when the action may go ahead. On `false` the request is already answered:
    ///   the page's promise settles with an error rather than hanging on something that will never
    ///   happen.
    func requireUserPresence(for message: BridgeMessage) -> Bool {
        guard !isUserPresent else { return true }

        respondError("Nobody is looking at this page", to: message)
        return false
    }
}

// MARK: - Capabilities

/// Hosts a page that steers its own life: it can report that it booted, ask to be closed or
/// hidden, and report a tap.
///
/// A capability, not a layer. Any page may send these — whether they mean anything depends on
/// who hosts it. A page sending `close` to a host that does not conform is not an error: the
/// message is journalled and dropped.
protocol WebBridgeLifecycleHosting: AnyObject {

    func bridgeDidInit()

    func bridgeDidRequestClose()

    func bridgeDidRequestHide()

    /// The click payload is forwarded verbatim: what a tap means is decided above the bridge.
    func bridgeDidClick(rawPayload: String)
}

/// Hosts a page that reports how much content it rendered.
///
/// Only the embedded block listens today. The day an in-app wants the same signal it conforms
/// here and the page simply starts sending `contentRendered` — nothing inside the bridge changes.
protocol WebBridgeContentHosting: AnyObject {

    /// - Parameter count: `0` means the page is alive and correct and has nothing to show.
    ///   That is an outcome, not a failure.
    func bridgeDidRenderContent(count: Int)
}
