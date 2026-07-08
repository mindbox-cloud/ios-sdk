//
//  InAppWebViewCacheTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 06.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import WebKit
@testable import Mindbox

@Suite("InApp WebView data store", .tags(.webView))
@MainActor
struct InAppWebViewDataStoreTests {

    /// Evaluates the lazily-initialized store here rather than first in a host app: a mangled
    /// identifier literal traps in CI. The properties are the ones the cache design rests on —
    /// one live instance (shared in-memory session), persistence (cache survives relaunch),
    /// isolation from the host app's default store, and the exact identifier value: changing
    /// it orphans every install's cached store, so it must never change unnoticed.
    @Test
    func sharedIsOneIsolatedPersistentStore() {
        let store = InAppWebViewDataStore.shared()
        #expect(store === InAppWebViewDataStore.shared())
        // iOS 17+: isolated persistent store. Below 17 the store IS .default() by product
        // decision (some disk cache beats none), so isolation is only asserted here.
        if #available(iOS 17.0, *) {
            #expect(store !== WKWebsiteDataStore.default())
            #expect(store.isPersistent)
            // UUIDv5 of "cloud.Mindbox.InAppWebViewDataStore" — see InAppWebViewDataStore.
            #expect(store.identifier == UUID(uuidString: "9E350642-BB9F-5D4C-9981-94FFD93C2B57"))
        }
    }

    /// Kill-switch semantics: only an explicit `false` disables; an absent key, absent
    /// section, or missing/unreadable config (nil from the repository) means enabled.
    @Test
    func cacheToggleResolvesFromCachedConfig() throws {
        func config(_ json: String) throws -> ConfigResponse {
            try JSONDecoder().decode(ConfigResponse.self, from: Data(json.utf8))
        }

        #expect(InAppWebViewDataStore.isCacheEnabled(in: nil))
        #expect(InAppWebViewDataStore.isCacheEnabled(in: try config(#"{"settings":{}}"#)))
        #expect(InAppWebViewDataStore.isCacheEnabled(in: try config(#"{"settings":{"featureToggles":{}}}"#)))
        #expect(InAppWebViewDataStore.isCacheEnabled(
            in: try config(#"{"settings":{"featureToggles":{"MobileSdkShouldCacheInAppWebView":true}}}"#)
        ))
        #expect(!InAppWebViewDataStore.isCacheEnabled(
            in: try config(#"{"settings":{"featureToggles":{"MobileSdkShouldCacheInAppWebView":false}}}"#)
        ))
    }

    @Test
    func webViewTogglesDecodeFromFeatureTogglesSection() throws {
        let json = #"{"settings":{"featureToggles":{"MobileSdkShouldPrewarmInAppWebView":false,"MobileSdkShouldCacheInAppWebView":true}}}"#
        let config = try JSONDecoder().decode(ConfigResponse.self, from: Data(json.utf8))

        let toggles = try #require(config.settings?.featureToggles)
        #expect(toggles.shouldPrewarmInAppWebView == false)
        #expect(toggles.shouldCacheInAppWebView == true)
    }
}

@Suite("InApp WebView HTML fetcher", .tags(.webView))
struct InAppWebViewHTMLFetcherTests {

    /// In the test process the cache toggle latches enabled (no cached config on disk),
    /// so this pins the caching path: revalidation, no host cookie jar, one stable session.
    @Test
    func cachingPathIsCookieLessRevalidatingAndStable() throws {
        let url = try #require(URL(string: "https://inapp.local/popup"))
        let (session, request) = InAppWebViewHTMLFetcher.sessionAndRequest(for: url)

        #expect(request.cachePolicy == .reloadRevalidatingCacheData)
        #expect(session !== URLSession.shared)
        #expect(session.configuration.httpShouldSetCookies == false)
        #expect(session.configuration.httpCookieStorage == nil)
        #expect(session.configuration.urlCache != nil)
        #expect(session.configuration.urlCache !== URLCache.shared)
        #expect(InAppWebViewHTMLFetcher.sessionAndRequest(for: url).session === session)
    }
}

@Suite("InApp WebView factory", .tags(.webView))
@MainActor
struct InAppWebViewFactoryTests {

    @Test
    func factoryConfiguresTheSharedStoreAndUserAgent() {
        let webView = InAppWebViewFactory.make(userAgent: "test-ua")
        #expect(webView.configuration.websiteDataStore === InAppWebViewDataStore.shared())
        #expect(webView.configuration.applicationNameForUserAgent == "test-ua")
        #expect(webView.configuration.allowsInlineMediaPlayback)
        #expect(InAppWebViewFactory.make().configuration.applicationNameForUserAgent == SDKUserAgent.build())
    }
}
