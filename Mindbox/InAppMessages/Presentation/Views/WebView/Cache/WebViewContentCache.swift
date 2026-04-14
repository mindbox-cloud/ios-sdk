//
//  WebViewContentCache.swift
//  Mindbox
//
//  Created by Mindbox on 06.04.2026.
//

import UIKit
import MindboxLogger

protocol WebViewContentCacheProtocol {
    func store(html: String, for contentUrl: String)
    func html(for contentUrl: String) -> String?
    func invalidateAll()
}

final class WebViewContentCache: WebViewContentCacheProtocol {

    private var memoryCache: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.Mindbox.webViewContentCache", attributes: .concurrent)
    private let diskDirectory: URL

    init() {
        // swiftlint:disable:next force_unwrapping
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskDirectory = cachesDir.appendingPathComponent("com.mindbox.webview-html", isDirectory: true)
        createDirectoryIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func store(html: String, for contentUrl: String) {
        queue.async(flags: .barrier) {
            self.memoryCache[contentUrl] = html
        }
        // Also persist to disk for offline access after app restart
        let fileURL = diskFileURL(for: contentUrl)
        queue.async(flags: .barrier) {
            try? html.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func html(for contentUrl: String) -> String? {
        // Try memory first
        if let cached = queue.sync(execute: { memoryCache[contentUrl] }) {
            return cached
        }
        // Fall back to disk
        let fileURL = diskFileURL(for: contentUrl)
        guard let html = queue.sync(execute: { try? String(contentsOf: fileURL, encoding: .utf8) }) else {
            return nil
        }
        // Promote to memory cache
        queue.async(flags: .barrier) {
            self.memoryCache[contentUrl] = html
        }
        Logger.common(
            message: "[WebView Preload] Loaded HTML from disk cache for \(contentUrl)",
            category: .webViewInAppMessages
        )
        return html
    }

    func invalidateAll() {
        queue.async(flags: .barrier) {
            self.memoryCache.removeAll()
            Logger.common(message: "[WebView Preload] HTML memory cache invalidated", category: .webViewInAppMessages)
        }
    }

    @objc
    private func didReceiveMemoryWarning() {
        // Only clear memory cache, keep disk
        queue.async(flags: .barrier) {
            self.memoryCache.removeAll()
            Logger.common(message: "[WebView Preload] HTML memory cache cleared (memory warning)", category: .webViewInAppMessages)
        }
    }

    // MARK: - Private

    private func diskFileURL(for contentUrl: String) -> URL {
        let hashData = SHA256().hash(data: Data(contentUrl.utf8))
        let hashString = hashData.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(hashString).appendingPathExtension("html")
    }

    private func createDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: diskDirectory.path) {
            try? fm.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
        }
    }
}
