//
//  WebViewJSCache.swift
//  Mindbox
//
//  Created by Mindbox on 13.04.2026.
//

import Foundation
import MindboxLogger

protocol WebViewJSCacheProtocol {
    func store(data: Data, for url: String)
    func data(for url: String) -> Data?
    func invalidateAll()
}

/// Disk-based cache for JavaScript resources used by webview in-apps.
///
/// Stores JS files in `Library/Caches/com.mindbox.webview-js/`,
/// keyed by a SHA-256 hash of the resource URL.
/// Used together with `MindboxCacheSchemeHandler` to serve JS offline
/// via the `mindbox-cache://` custom URL scheme.
final class WebViewJSCache: WebViewJSCacheProtocol {

    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.Mindbox.webViewJSCache", attributes: .concurrent)

    init() {
        // swiftlint:disable:next force_unwrapping
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDir.appendingPathComponent("com.mindbox.webview-js", isDirectory: true)
        createDirectoryIfNeeded()
    }

    func store(data: Data, for url: String) {
        let fileURL = fileURL(for: url)
        queue.async(flags: .barrier) {
            do {
                try data.write(to: fileURL, options: .atomic)
                Logger.common(
                    message: "[JS Cache] Stored \(url) (\(data.count) bytes)",
                    category: .webViewInAppMessages
                )
            } catch {
                Logger.common(
                    message: "[JS Cache] Failed to store \(url): \(error.localizedDescription)",
                    level: .error,
                    category: .webViewInAppMessages
                )
            }
        }
    }

    func data(for url: String) -> Data? {
        let fileURL = fileURL(for: url)
        return queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            return try? Data(contentsOf: fileURL)
        }
    }

    func invalidateAll() {
        queue.async(flags: .barrier) {
            do {
                if FileManager.default.fileExists(atPath: self.cacheDirectory.path) {
                    try FileManager.default.removeItem(at: self.cacheDirectory)
                    self.createDirectoryIfNeeded()
                }
                Logger.common(
                    message: "[JS Cache] Cache invalidated",
                    category: .webViewInAppMessages
                )
            } catch {
                Logger.common(
                    message: "[JS Cache] Failed to invalidate: \(error.localizedDescription)",
                    level: .error,
                    category: .webViewInAppMessages
                )
            }
        }
    }

    // MARK: - Private

    private func fileURL(for url: String) -> URL {
        let hashData = SHA256().hash(data: Data(url.utf8))
        let hashString = hashData.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(hashString).appendingPathExtension("js")
    }

    private func createDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory.path) {
            try? fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
}
