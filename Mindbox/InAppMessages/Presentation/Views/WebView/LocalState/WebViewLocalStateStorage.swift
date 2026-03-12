//
//  WebViewLocalStateStorage.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/11/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct WebViewLocalState {
    let version: Int
    let data: [String: String]
}

protocol WebViewLocalStateStorageProtocol: AnyObject {
    func get(keys: [String]) -> WebViewLocalState
    func set(data: [String: String?]) -> WebViewLocalState
    func initialize(version: Int, data: [String: String?]) -> WebViewLocalState?
}

final class WebViewLocalStateStorage: WebViewLocalStateStorageProtocol {
    private static let keyPrefix = Constants.WebViewLocalState.keyPrefix

    private let dataDefaults: UserDefaults
    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.dataDefaults = UserDefaults(suiteName: Constants.WebViewLocalState.suiteName)
            ?? UserDefaults.standard
        self.persistenceStorage = persistenceStorage
    }

    /// For testing — inject custom UserDefaults
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

    /// Merges provided data into existing state. A `nil` value removes the key.
    func set(data: [String: String?]) -> WebViewLocalState {
        applyData(data)
        let version = persistenceStorage.webViewLocalStateVersion ?? Constants.WebViewLocalState.defaultVersion
        return WebViewLocalState(version: version, data: load(keys: Array(data.keys)))
    }

    /// Merges data (like `set`) and updates version. Version must be a positive integer.
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
