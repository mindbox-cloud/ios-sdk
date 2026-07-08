//
//  InAppWebViewHTMLFetcher.swift
//  Mindbox
//
//  Created by Sergei Semko on 07.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// The single home of the in-app HTML fetch transport: the prewarm and the shows MUST use
/// identical cache semantics, or the prewarm fills a cache the shows never read.
enum InAppWebViewHTMLFetcher {

    /// Caching path: revalidates with the server on every fetch (ETag match → a ~0-byte 304
    /// and the cache supplies the stored body). A dedicated cookie-less session keeps the
    /// SDK out of the host app's shared cookie jar and URLCache — the pre-feature fetch
    /// carried no cookies either.
    private static let cachingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        if #available(iOS 13.0, *) {
            // Holds ONLY the in-app index HTML (a few small entries per endpoint) — page
            // resources live in WebKit's own cache. Sized accordingly.
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("cloud.Mindbox.InAppWebViewHTML", isDirectory: true)
            config.urlCache = URLCache(memoryCapacity: 512 * 1024,
                                       diskCapacity: 4 * 1024 * 1024,
                                       directory: directory)
        }
        return URLSession(configuration: config)
    }()

    /// Cache-less path — the exact pre-feature transport.
    private static let ephemeralSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func sessionAndRequest(for url: URL) -> (session: URLSession, request: URLRequest) {
        // Foundation implements .reloadRevalidatingCacheData starting with iOS 13; on
        // iOS 12 it silently degrades to the protocol policy and could serve a stale
        // index without a server round-trip — old systems keep the cache-less fetch.
        guard #available(iOS 13.0, *), InAppWebViewDataStore.isCacheFeatureEnabled else {
            return (ephemeralSession, URLRequest(url: url))
        }
        return (cachingSession, URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
    }
}
