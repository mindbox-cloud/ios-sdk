//
//  WebViewLocalStateStorage.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/11/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// Snapshot of local state: stored key-value data and schema version.
struct WebViewLocalState {
    /// Schema version, stored in `PersistenceStorage`. Starts at 1.
    let version: Int
    /// Key-value data, stored in `UserDefaults` with a namespaced prefix.
    let data: [String: String]
}

/// On-device key-value storage for WebView in-app messages.
///
/// Data is persisted in a dedicated `UserDefaults` suite with prefixed keys.
/// Schema version is stored separately in `PersistenceStorage`.
///
/// Used by bridge actions `localState.get`, `localState.set`, `localState.init`.
protocol WebViewLocalStateStorageProtocol: AnyObject {
    /// Returns stored values for the given keys, or **all** values if `keys` is empty.
    func get(keys: [String]) -> WebViewLocalState

    /// Merges provided data into existing state. A `nil` value removes the key.
    /// Returns the updated state for the affected keys.
    func set(data: [String: String?]) -> WebViewLocalState

    /// Merges data and updates schema version. Version must be positive.
    /// Always applies data regardless of current version (no skip on same version).
    /// Returns `nil` if version is invalid (<= 0).
    func initialize(version: Int, data: [String: String?]) -> WebViewLocalState?
}

/// On-device key-value storage backed by `UserDefaults`.
///
/// Keys are prefixed with a namespace to avoid collisions with the host app's own UserDefaults keys.
/// All values are stored as strings. Version is stored in `PersistenceStorage`.
final class WebViewLocalStateStorage: WebViewLocalStateStorageProtocol {
    private static let keyPrefix = Constants.WebViewLocalState.keyPrefix

    private let dataDefaults: UserDefaults
    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.dataDefaults = UserDefaults(suiteName: Constants.WebViewLocalState.suiteName)
            ?? UserDefaults.standard
        self.persistenceStorage = persistenceStorage
    }

    init(dataDefaults: UserDefaults, persistenceStorage: PersistenceStorage) {
        self.dataDefaults = dataDefaults
        self.persistenceStorage = persistenceStorage
    }

    func get(keys: [String]) -> WebViewLocalState {
        let version = persistenceStorage.webViewLocalStateVersion ?? Constants.WebViewLocalState.defaultVersion

        if keys.isEmpty {
            return WebViewLocalState(version: version, data: loadAll())
        }

        var data: [String: String] = [:]
        for key in keys {
            if let value = dataDefaults.string(forKey: Self.prefixed(key)) {
                data[key] = value
            }
        }
        return WebViewLocalState(version: version, data: data)
    }

    func set(data: [String: String?]) -> WebViewLocalState {
        applyData(data)
        let version = persistenceStorage.webViewLocalStateVersion ?? Constants.WebViewLocalState.defaultVersion
        return WebViewLocalState(version: version, data: load(keys: Array(data.keys)))
    }

    func initialize(version: Int, data: [String: String?]) -> WebViewLocalState? {
        guard version > 0 else {
            Logger.common(
                message: "[WebView] localState.init rejected: version must be positive, got \(version)",
                level: .error,
                category: .webViewInAppMessages
            )
            return nil
        }

        persistenceStorage.webViewLocalStateVersion = version
        applyData(data)
        return WebViewLocalState(version: version, data: load(keys: Array(data.keys)))
    }

    // MARK: - Private

    private func applyData(_ data: [String: String?]) {
        for (key, value) in data {
            if let value = value {
                dataDefaults.set(value, forKey: Self.prefixed(key))
            } else {
                dataDefaults.removeObject(forKey: Self.prefixed(key))
            }
        }
    }

    private static func prefixed(_ key: String) -> String {
        keyPrefix + key
    }

    private func load(keys: [String]) -> [String: String] {
        var data: [String: String] = [:]
        for key in keys {
            if let value = dataDefaults.string(forKey: Self.prefixed(key)) {
                data[key] = value
            }
        }
        return data
    }

    private func loadAll() -> [String: String] {
        var data: [String: String] = [:]
        for (key, value) in dataDefaults.dictionaryRepresentation() {
            guard key.hasPrefix(Self.keyPrefix), let stringValue = value as? String else {
                continue
            }
            data[String(key.dropFirst(Self.keyPrefix.count))] = stringValue
        }
        return data
    }
}
