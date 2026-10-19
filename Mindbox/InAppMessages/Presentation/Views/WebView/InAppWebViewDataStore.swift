//
//  InAppWebViewDataStore.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

enum InAppWebViewDataStore {
    // Changing it orphans the WebView store on every existing install.
    // swiftlint:disable:next force_unwrapping
    private static let identifier = UUID(uuidString: "9E350642-BB9F-5D4C-9981-94FFD93C2B57")!

    static let isCacheFeatureEnabled: Bool =
        isCacheEnabled(in: InAppConfigurationRepository().fetchDecodedConfigFromCache())

    static func isCacheEnabled(in config: ConfigResponse?) -> Bool {
        config?.settings?.featureToggles?.shouldCacheInAppWebView
            ?? FeatureFlag.shouldCacheInAppWebView.defaultValue
    }

    private static let instance: WKWebsiteDataStore = {
        if #available(iOS 17.0, *) {
            return WKWebsiteDataStore(forIdentifier: identifier)
        } else {
            return WKWebsiteDataStore.default()
        }
    }()

    static func shared() -> WKWebsiteDataStore {
        guard isCacheFeatureEnabled else { return WKWebsiteDataStore.nonPersistent() }
        return instance
    }

    static func purgeCache(forHostOf urlString: String?, completion: @escaping (_ didRemoveAnything: Bool) -> Void) {
        let cacheTypes: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        let store = shared()
        let trimmedURLString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = trimmedURLString.flatMap(URL.init(string:))?.host?.lowercased()
        let isIsolatedStore: Bool = {
            if #available(iOS 17.0, *) { return isCacheFeatureEnabled }
            return false
        }()
        let finish: (Bool) -> Void = { didRemoveAnything in
            if Thread.isMainThread {
                completion(didRemoveAnything)
            } else {
                DispatchQueue.main.async { completion(didRemoveAnything) }
            }
        }
        store.fetchDataRecords(ofTypes: cacheTypes) { records in
            let matching = records.filter { record in
                guard let host else { return false }
                let domain = record.displayName.lowercased()
                return host == domain || host.hasSuffix("." + domain)
            }
            Logger.common(message: "[WebView] Cache purge for host \(host ?? "nil"): \(matching.isEmpty ? "no matching records" : "removing \(matching.count) record(s)")",
                          level: .debug, category: .webViewInAppMessages)
            if !matching.isEmpty {
                store.removeData(ofTypes: cacheTypes, for: matching) { finish(true) }
            } else if isIsolatedStore {
                store.removeData(ofTypes: cacheTypes, modifiedSince: .distantPast) { finish(false) }
            } else {
                finish(false)
            }
        }
    }
}
