//
//  InAppWebViewDataStore.swift
//  Mindbox
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit

/// The single `WKWebsiteDataStore` used by every Mindbox WebView (prewarm and shows alike).
///
/// Persistence is what lets WebKit's header-driven HTTP cache survive relaunches. The disk
/// cache is keyed per data store, so the prewarm and the shows MUST share this instance for
/// prewarmed entries to be visible to shows.
///
/// On iOS 17+ the store is isolated from the host app's `.default()` store so Mindbox web
/// content never shares cookies/storage with the host's own WebViews. Earlier systems fall
/// back to `.default()` — a deliberate product decision: some disk cache beats none, and
/// sharing the host's store is accepted there. The cache kill switch still restores the
/// pre-feature `.nonPersistent()` isolation on every OS.
enum InAppWebViewDataStore {
    // Stable identifier for the isolated store; changing it orphans the previous store.
    // UUIDv5 (SHA-1, RFC 4122 DNS namespace) of "cloud.Mindbox.InAppWebViewDataStore":
    // python3 -c 'import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, "cloud.Mindbox.InAppWebViewDataStore"))'
    // swiftlint:disable:next force_unwrapping
    private static let identifier = UUID(uuidString: "9E350642-BB9F-5D4C-9981-94FFD93C2B57")!

    /// The cache half of the WebView feature toggles. Latched at first WebView creation for
    /// the rest of the launch: flipping stores mid-session would split the cache between
    /// partitions. Read from the config cache, which holds the freshest config the SDK has
    /// seen — a freshly downloaded config is saved there before any show or stage-2 prewarm
    /// can run.
    static let isCacheFeatureEnabled: Bool =
        isCacheEnabled(in: InAppConfigurationRepository().fetchDecodedConfigFromCache())

    /// Absent key, absent section, absent/unreadable config all mean "enabled" — the toggle
    /// is a kill switch, not an opt-in.
    static func isCacheEnabled(in config: ConfigResponse?) -> Bool {
        config?.settings?.featureToggles?.shouldCacheInAppWebView
            ?? FeatureFlag.shouldCacheInAppWebView.defaultValue
    }

    // One live store object per process: a single instance also guarantees prewarm and
    // shows share the same in-memory session (connection pool, memory cache).
    private static let instance: WKWebsiteDataStore = {
        if #available(iOS 17.0, *) {
            return WKWebsiteDataStore(forIdentifier: identifier)
        } else {
            // Product decision: no isolated named stores before iOS 17, and some disk
            // cache beats none — Mindbox web content shares the host app's default store
            // (cookies/storage included) on old systems.
            return WKWebsiteDataStore.default()
        }
    }()

    static func shared() -> WKWebsiteDataStore {
        // Toggle off restores the pre-feature behavior exactly: every WebView gets its
        // own fresh in-memory store, nothing is shared and nothing persists.
        guard isCacheFeatureEnabled else { return WKWebsiteDataStore.nonPersistent() }
        return instance
    }
}
