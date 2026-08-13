//
//  PermissionActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Asks the system for a permission on the page's behalf.
///
/// The answer says both what the user's stance is and whether a dialog was actually shown, so
/// the page can tell a fresh refusal from a standing one and offer settings instead of asking
/// again into a void.
final class PermissionActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.permissionRequest]

    /// Resolved on first use: a handler set is built for every show, and most pages never ask
    /// for a permission.
    private lazy var registry: PermissionHandlerRegistryProtocol = makeRegistry()

    private let makeRegistry: () -> PermissionHandlerRegistryProtocol
    private let infoPlistValue: (String) -> Any?

    init(makeRegistry: @escaping () -> PermissionHandlerRegistryProtocol
         = { DI.injectOrFail(PermissionHandlerRegistryProtocol.self) },
         infoPlistValue: @escaping (String) -> Any? = { Bundle.main.object(forInfoDictionaryKey: $0) }) {
        self.makeRegistry = makeRegistry
        self.infoPlistValue = infoPlistValue
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        guard case .string(let typeString)? = message.payloadObject?["type"], !typeString.isEmpty else {
            host.respondError("Invalid payload: missing or empty 'type' field", to: message)
            return
        }

        guard let type = PermissionType(rawValue: typeString) else {
            host.respondError("Unknown permission type: '\(typeString)'", to: message)
            return
        }

        guard let handler = registry.handler(for: type) else {
            host.respondError("No handler registered for permission type: '\(typeString)'", to: message)
            return
        }

        // Asking without the usage description in place would kill the host app rather than
        // return a refusal, so the missing key is reported to the page instead.
        for key in handler.requiredInfoPlistKeys where infoPlistValue(key) == nil {
            host.respondError("Missing Info.plist key: \(key)", to: message)
            return
        }

        handler.request { result in
            DispatchQueue.main.async {
                switch result {
                case .granted(let dialogShown):
                    Self.respond("granted", dialogShown: dialogShown, to: message, host: host)
                case .denied(let dialogShown):
                    Self.respond("denied", dialogShown: dialogShown, to: message, host: host)
                case .error(let reason):
                    host.respondError(reason, to: message)
                }
            }
        }
    }

    private static func respond(_ result: String,
                                dialogShown: Bool,
                                to message: BridgeMessage,
                                host: WebBridgeHost) {
        host.respond(to: message, payload: .object([
            "result": .string(result),
            "dialogShown": .bool(dialogShown)
        ]))
    }
}
