//
//  MindboxCacheSchemeHandler.swift
//  Mindbox
//
//  Created by Mindbox on 13.04.2026.
//

import WebKit
import MindboxLogger

/// Custom URL scheme: `mindbox-cache://`
///
/// Intercepts requests to `mindbox-cache://` URLs and serves JavaScript resources
/// from the on-disk `WebViewJSCache`. This enables offline display of webview in-apps:
/// the SDK rewrites `<script src="https://cdn/tracker.js">` → `<script src="mindbox-cache://tracker.js">`
/// before loading HTML, and this handler serves the JS from local storage.
final class MindboxCacheSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "mindbox-cache"

    private let jsCache: WebViewJSCacheProtocol

    init(jsCache: WebViewJSCacheProtocol) {
        self.jsCache = jsCache
        super.init()
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            fail(urlSchemeTask, code: .badURL, message: "Missing URL in scheme task request")
            return
        }

        // Recover original https URL from the mindbox-cache:// URL.
        // mindbox-cache://host/path → https://host/path
        guard let originalURL = originalHTTPSURL(from: url) else {
            fail(urlSchemeTask, code: .badURL, message: "Cannot reconstruct original URL from \(url.absoluteString)")
            return
        }

        let originalURLString = originalURL.absoluteString

        guard let data = jsCache.data(for: originalURLString) else {
            Logger.common(
                message: "[SchemeHandler] Cache miss for \(originalURLString)",
                level: .error,
                category: .webViewInAppMessages
            )
            fail(urlSchemeTask, code: .fileDoesNotExist, message: "No cached data for \(originalURLString)")
            return
        }

        Logger.common(
            message: "[SchemeHandler] Serving \(originalURLString) from cache (\(data.count) bytes)",
            category: .webViewInAppMessages
        )

        let mimeType = guessMIMEType(for: url)
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Nothing to cancel — data is served synchronously from disk.
    }

    // MARK: - Private

    /// Converts `mindbox-cache://host/path` back to `https://host/path`.
    private func originalHTTPSURL(from cacheURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = cacheURL.host
        components.path = cacheURL.path
        components.query = cacheURL.query
        return components.url
    }

    private func guessMIMEType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "js":
            return "application/javascript"
        case "css":
            return "text/css"
        case "html", "htm":
            return "text/html"
        case "json":
            return "application/json"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "svg":
            return "image/svg+xml"
        default:
            return "application/octet-stream"
        }
    }

    private func fail(_ task: WKURLSchemeTask, code: URLError.Code, message: String) {
        Logger.common(
            message: "[SchemeHandler] Error: \(message)",
            level: .error,
            category: .webViewInAppMessages
        )
        task.didFailWithError(URLError(code))
    }
}
