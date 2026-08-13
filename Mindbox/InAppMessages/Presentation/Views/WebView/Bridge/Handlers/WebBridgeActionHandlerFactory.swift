//
//  WebBridgeActionHandlerFactory.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Assembles the handler set a bridge session runs with.
///
/// One set, the same for every WebView. There is no per-surface list on purpose: an action a
/// host does not listen for is journalled and dropped, so a page may speak the whole vocabulary
/// wherever it lives. Teaching a new surface an existing action is a conformance on that host,
/// not a new entry here.
enum WebBridgeActionHandlerFactory {

    /// Fresh instances every call: several handlers keep state belonging to one page — a
    /// prepared haptic engine, a motion subscription — which has to die with that page.
    static func makeHandlers() -> [WebBridgeActionHandler] {
        [
            LogActionHandler(),
            LocalStateActionHandler(),
            OpenLinkActionHandler(),
            SettingsActionHandler(),
            PermissionActionHandler()
        ]
    }
}
