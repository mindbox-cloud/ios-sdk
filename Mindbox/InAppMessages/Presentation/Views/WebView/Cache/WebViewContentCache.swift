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

    private var cache: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.Mindbox.webViewContentCache", attributes: .concurrent)

    init() {
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
            self.cache[contentUrl] = html
        }
    }

    func html(for contentUrl: String) -> String? {
        queue.sync {
            cache[contentUrl]
        }
    }

    func invalidateAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            Logger.common(message: "[WebView Preload] HTML cache invalidated", category: .webViewInAppMessages)
        }
    }

    @objc
    private func didReceiveMemoryWarning() {
        invalidateAll()
    }
}
