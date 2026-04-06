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
    func invalidateCache()
}

final class WebViewContentPreloader: WebViewContentPreloaderProtocol {

    private let cache: WebViewContentCacheProtocol
    private let session: URLSession

    init(cache: WebViewContentCacheProtocol) {
        self.cache = cache
        self.session = URLSession(configuration: .default)
    }

    func preloadContent(from config: ConfigResponse) {
        let urls = extractWebViewContentURLs(from: config)
        guard !urls.isEmpty else { return }

        Logger.common(
            message: "[WebView Preload] Starting preload for \(urls.count) unique URL(s)",
            category: .webViewInAppMessages
        )

        for urlString in urls {
            guard cache.html(for: urlString) == nil else {
                Logger.common(
                    message: "[WebView Preload] Already cached: \(urlString)",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                continue
            }
            downloadHTML(from: urlString)
        }
    }

    func cachedHTML(for contentUrl: String) -> String? {
        cache.html(for: contentUrl)
    }

    func invalidateCache() {
        cache.invalidateAll()
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

        let task = session.dataTask(with: url) { [weak self] data, response, error in
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
