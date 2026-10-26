//
//  LocalStateActionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class LocalStateActionHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action> = [.localStateGet, .localStateSet, .localStateInit]

    private lazy var storage: WebViewLocalStateStorageProtocol = makeStorage()

    private let makeStorage: () -> WebViewLocalStateStorageProtocol
    private let webPageRegistry: MindboxWebPageRegistry

    init(makeStorage: @escaping () -> WebViewLocalStateStorageProtocol
         = { DI.injectOrFail(WebViewLocalStateStorageProtocol.self) },
         webPageRegistry: MindboxWebPageRegistry = .shared) {
        self.makeStorage = makeStorage
        self.webPageRegistry = webPageRegistry
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        switch message.parsedAction {
        case .localStateGet:
            get(message, host: host)
        case .localStateSet:
            set(message, host: host)
        case .localStateInit:
            initialize(message, host: host)
        default:
            break
        }
    }
}

// MARK: - Actions

private extension LocalStateActionHandler {

    func get(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject else {
            host.respondError(.invalidPayload, detail: "payload is not a JSON object", to: message)
            return
        }

        let keys: [String]
        if case .array(let requested) = payload["data"] {
            keys = requested.compactMap { if case .string(let key) = $0 { return key } else { return nil } }
        } else {
            keys = []
        }

        let state = storage.get(keys: keys)

        Logger.common(
            message: "[WebView] localState.get keys=\(keys) → \(state.data.count) entries, version=\(state.version)",
            level: .info,
            category: host.logCategory
        )

        var stored: [String: JSONValue] = [:]
        if keys.isEmpty {
            for (key, value) in state.data {
                stored[key] = .string(value)
            }
        } else {
            for key in keys {
                stored[key] = state.data[key].map { .string($0) } ?? .null
            }
        }

        host.respond(to: message, payload: .object([
            "data": .object(stored),
            "version": .int(state.version)
        ]))
    }

    func set(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject,
              case .object(let entries) = payload["data"] else {
            host.respondError(.invalidPayload, detail: "missing 'data' object", to: message)
            return
        }

        let data = Self.storable(entries)
        let state = storage.set(data: data)

        Logger.common(
            message: "[WebView] localState.set \(data.count) keys → version=\(state.version)",
            level: .info,
            category: host.logCategory
        )

        let answer = Self.payload(for: data, version: state.version)
        host.respond(to: message, payload: answer)

        webPageRegistry.broadcast(.localStateChanged, payload: answer, excluding: host)
    }

    func initialize(_ message: BridgeMessage, host: WebBridgeHost) {
        guard let payload = message.payloadObject,
              case .int(let version) = payload["version"],
              case .object(let entries) = payload["data"] else {
            host.respondError(.invalidPayload, detail: "missing 'version' or 'data'", to: message)
            return
        }

        let data = Self.storable(entries)

        guard let state = storage.initialize(version: version, data: data) else {
            host.respondError(.invalidPayload, detail: "version must be a positive integer, got \(version)", to: message)
            return
        }

        Logger.common(
            message: "[WebView] localState.init version=\(version), \(data.count) keys",
            level: .info,
            category: host.logCategory
        )

        host.respond(to: message, payload: Self.payload(for: data, version: state.version))
    }
}

// MARK: - Conversion

private extension LocalStateActionHandler {

    static func storable(_ entries: [String: JSONValue]) -> [String: String?] {
        var data: [String: String?] = [:]

        for (key, value) in entries {
            switch value {
            case .string(let string):
                data[key] = string
            case .null:
                data[key] = nil as String?
            default:
                if let encoded = try? JSONEncoder().encode(value),
                   let string = String(data: encoded, encoding: .utf8) {
                    data[key] = string
                }
            }
        }

        return data
    }

    static func payload(for data: [String: String?], version: Int) -> JSONValue {
        var stored: [String: JSONValue] = [:]

        for (key, value) in data {
            stored[key] = value.map { .string($0) } ?? .null
        }

        return .object([
            "data": .object(stored),
            "version": .int(version)
        ])
    }
}
