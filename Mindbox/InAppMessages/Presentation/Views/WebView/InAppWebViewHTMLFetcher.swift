//
//  InAppWebViewHTMLFetcher.swift
//  Mindbox
//
//  Created by Sergei Semko on 07.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum InAppWebViewHTMLFetcher {

    private static let cachingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        if #available(iOS 13.0, *) {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("cloud.Mindbox.InAppWebViewHTML", isDirectory: true)
            config.urlCache = URLCache(memoryCapacity: 512 * 1024,
                                       diskCapacity: 4 * 1024 * 1024,
                                       directory: directory)
        }
        return URLSession(configuration: config)
    }()

    private static let ephemeralSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func sessionAndRequest(for url: URL) -> (session: URLSession, request: URLRequest) {
        // Before iOS 13 Foundation ignores .reloadRevalidatingCacheData and may serve a stale index.
        guard #available(iOS 13.0, *), InAppWebViewDataStore.isCacheFeatureEnabled else {
            return (ephemeralSession, URLRequest(url: url))
        }
        return (cachingSession, URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
    }
}
