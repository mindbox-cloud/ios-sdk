//
//  PermissionActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class PermissionActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.permissionRequest]

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
            host.respondError(.invalidPayload, detail: "missing or empty 'type' field", to: message)
            return
        }

        guard let type = PermissionType(rawValue: typeString) else {
            host.respondError(.unsupportedValue, detail: "unknown permission type '\(typeString)'", to: message)
            return
        }

        guard let handler = registry.handler(for: type) else {
            host.respondError(.internalError, detail: "no handler registered for permission type '\(typeString)'", to: message)
            return
        }

        for key in handler.requiredInfoPlistKeys where infoPlistValue(key) == nil {
            host.respondError(.permissionFailed, detail: "missing Info.plist key \(key)", to: message)
            return
        }

        handler.request { [weak host] result in
            DispatchQueue.main.async {
                guard let host else { return }

                switch result {
                case .granted(let dialogShown):
                    Self.respond("granted", dialogShown: dialogShown, to: message, host: host)
                case .denied(let dialogShown):
                    Self.respond("denied", dialogShown: dialogShown, to: message, host: host)
                case .error(let reason):
                    host.respondError(.permissionFailed, detail: reason, to: message)
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
