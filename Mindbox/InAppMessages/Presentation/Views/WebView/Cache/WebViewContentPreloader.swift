//
//  WebViewContentPreloader.swift
//  Mindbox
//
//  Created by Mindbox on 06.04.2026.
//

import Foundation
import MindboxLogger

protocol WebViewContentPreloaderProtocol: AnyObject {
    func preloadContent(from config: ConfigResponse)
    func cachedHTML(for contentUrl: String) -> String?
    func cachedHTMLWithRewrittenScripts(for contentUrl: String) -> String?
    func invalidateCache()

    /// Called once when the first HTML becomes available (from disk cache or network download).
    /// Used to trigger warmUp as early as possible instead of waiting an arbitrary delay.
    var onHTMLCached: (() -> Void)? { get set }
}

final class WebViewContentPreloader: WebViewContentPreloaderProtocol {

    private let cache: WebViewContentCacheProtocol
    private let jsCache: WebViewJSCacheProtocol
    private let session: URLSession
    var onHTMLCached: (() -> Void)?

    init(cache: WebViewContentCacheProtocol, jsCache: WebViewJSCacheProtocol) {
        self.cache = cache
        self.jsCache = jsCache
        self.session = URLSession(configuration: .default)
    }

    func preloadContent(from config: ConfigResponse) {
        let urls = extractWebViewContentURLs(from: config)
        guard !urls.isEmpty else { return }

        Logger.common(
            message: "[WebView Preload] Starting preload for \(urls.count) unique URL(s)",
            category: .webViewInAppMessages
        )

        var hasAnyCached = false
        for urlString in urls {
            guard cache.html(for: urlString) == nil else {
                Logger.common(
                    message: "[WebView Preload] Already cached: \(urlString)",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                hasAnyCached = true
                continue
            }
            downloadHTML(from: urlString)
        }

        // If HTML is already cached from a previous session (disk), trigger warmUp immediately
        if hasAnyCached {
            fireOnHTMLCached()
        }
    }

    func cachedHTML(for contentUrl: String) -> String? {
        cache.html(for: contentUrl)
    }

    func cachedHTMLWithRewrittenScripts(for contentUrl: String) -> String? {
        guard let html = cache.html(for: contentUrl) else { return nil }
        let result = HTMLScriptURLRewriter.rewrite(html)
        return result.html
    }

    func invalidateCache() {
        cache.invalidateAll()
    }

    private func fireOnHTMLCached() {
        let callback = onHTMLCached
        onHTMLCached = nil
        DispatchQueue.main.async {
            callback?()
        }
    }

    // MARK: - Private

    private func downloadHTML(from urlString: String) {
        guard let url = URL(string: urlString) else {
            Logger.common(
                message: "[WebView Preload] Invalid URL: \(urlString)",
                level: .error,
                category: .webViewInAppMessages
            )
            return
        }

        let downloadStart = CFAbsoluteTimeGetCurrent()
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            let ms = Int((CFAbsoluteTimeGetCurrent() - downloadStart) * 1000)
            WebViewLoadingTracker.log("html_downloaded | \(ms)ms — \(urlString)")
            self?.handleDownloadResult(urlString: urlString, data: data, response: response, error: error)
        }

        task.resume()
    }

    private func handleDownloadResult(urlString: String, data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            Logger.common(
                message: "[WebView Preload] Failed to download \(urlString): \(error.localizedDescription)",
                level: .error,
                category: .webViewInAppMessages
            )
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            Logger.common(
                message: "[WebView Preload] Non-success HTTP response for \(urlString)",
                level: .error,
                category: .webViewInAppMessages
            )
            return
        }

        guard let data = data,
              let html = String(data: data, encoding: .utf8) else {
            Logger.common(
                message: "[WebView Preload] Failed to decode HTML from \(urlString)",
                level: .error,
                category: .webViewInAppMessages
            )
            return
        }

        cache.store(html: html, for: urlString)
        Logger.common(
            message: "[WebView Preload] Cached HTML for \(urlString) (\(html.count) chars)",
            category: .webViewInAppMessages
        )

        // Notify that HTML is ready — trigger warmUp ASAP
        fireOnHTMLCached()

        // Parse HTML for script URLs and pre-download JS resources
        let rewriteResult = HTMLScriptURLRewriter.rewrite(html)
        for scriptURL in rewriteResult.scriptURLs {
            downloadJS(from: scriptURL)
        }
    }

    private func downloadJS(from urlString: String) {
        // Skip if already cached
        guard jsCache.data(for: urlString) == nil else {
            Logger.common(
                message: "[JS Preload] Already cached: \(urlString)",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        guard let url = URL(string: urlString) else {
            Logger.common(
                message: "[JS Preload] Invalid URL: \(urlString)",
                level: .error,
                category: .webViewInAppMessages
            )
            return
        }

        Logger.common(
            message: "[JS Preload] Downloading \(urlString)",
            category: .webViewInAppMessages
        )

        let downloadStart = CFAbsoluteTimeGetCurrent()
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            let ms = Int((CFAbsoluteTimeGetCurrent() - downloadStart) * 1000)
            WebViewLoadingTracker.log("js_downloaded | \(ms)ms — \(urlString)")
            if let error {
                Logger.common(
                    message: "[JS Preload] Failed to download \(urlString): \(error.localizedDescription)",
                    level: .error,
                    category: .webViewInAppMessages
                )
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                Logger.common(
                    message: "[JS Preload] Non-success HTTP response for \(urlString)",
                    level: .error,
                    category: .webViewInAppMessages
                )
                return
            }

            guard let data, !data.isEmpty else {
                Logger.common(
                    message: "[JS Preload] Empty data for \(urlString)",
                    level: .error,
                    category: .webViewInAppMessages
                )
                return
            }

            self?.jsCache.store(data: data, for: urlString)
            Logger.common(
                message: "[JS Preload] Cached \(urlString) (\(data.count) bytes)",
                category: .webViewInAppMessages
            )
        }
        task.resume()
    }

    private func extractWebViewContentURLs(from config: ConfigResponse) -> Set<String> {
        var urls = Set<String>()

        guard let inapps = config.inapps?.elements else {
            return urls
        }

        for inapp in inapps {
            guard let variants = inapp.form.variants else { continue }
            for variant in variants {
                switch variant {
                case .modal(let modal):
                    if let layers = modal.content?.background?.layers {
                        for layer in layers {
                            if case .webview(let webviewLayer) = layer,
                               let contentUrl = webviewLayer.contentUrl,
                               !contentUrl.isEmpty {
                                urls.insert(contentUrl)
                            }
                        }
                    }
                case .snackbar(let snackbar):
                    if let layers = snackbar.content?.background?.layers {
                        for layer in layers {
                            if case .webview(let webviewLayer) = layer,
                               let contentUrl = webviewLayer.contentUrl,
                               !contentUrl.isEmpty {
                                urls.insert(contentUrl)
                            }
                        }
                    }
                case .unknown:
                    break
                }
            }
        }

        return urls
    }
}
