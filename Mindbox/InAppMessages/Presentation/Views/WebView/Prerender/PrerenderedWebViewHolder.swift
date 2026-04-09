//
//  PrerenderedWebViewHolder.swift
//  Mindbox
//
//  Created by Mindbox on 06.04.2026.
//

import UIKit
import MindboxLogger

struct PrerenderedWebView {
    let transparentView: TransparentView
    let webviewLayer: WebviewContentBackgroundLayer
    let inAppId: String
}

protocol PrerenderedWebViewHolderProtocol: AnyObject {
    func prerender(from config: ConfigResponse)
    func hasPrerendered(inAppId: String) -> Bool
    func claim(inAppId: String) -> PrerenderedWebView?
    func invalidate()
}

final class PrerenderedWebViewHolder: PrerenderedWebViewHolderProtocol {

    /// Maximum number of pre-rendered WebViews to keep in the pool.
    /// Each additional WKWebView in a shared process pool costs ~10-15MB.
    /// Default 3 = ~30-45MB overhead.
    static let defaultMaxPoolSize = 3

    private var pool: [String: PrerenderedWebView] = [:]  // inAppId → PrerenderedWebView
    private let maxPoolSize: Int
    private let preloader: WebViewContentPreloaderProtocol

    init(preloader: WebViewContentPreloaderProtocol, maxPoolSize: Int = PrerenderedWebViewHolder.defaultMaxPoolSize) {
        self.preloader = preloader
        self.maxPoolSize = maxPoolSize
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

    func prerender(from config: ConfigResponse) {
        let candidates = selectCandidates(from: config, limit: maxPoolSize)

        if candidates.isEmpty {
            Logger.common(
                message: "[WebView Prerender] No webview in-app candidates found for pre-rendering",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        Logger.common(
            message: "[WebView Prerender] Starting pre-render for \(candidates.count) candidate(s) (pool max=\(maxPoolSize))",
            category: .webViewInAppMessages
        )

        let userAgent = createUserAgent()

        for candidate in candidates {
            // Skip if already prerendered
            if pool[candidate.inAppId] != nil {
                continue
            }

            guard let cachedHTML = preloader.cachedHTML(for: candidate.webviewLayer.contentUrl) else {
                Logger.common(
                    message: "[WebView Prerender] HTML not yet cached for \(candidate.webviewLayer.contentUrl), skipping pre-render",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                continue
            }

            let transparentView = TransparentView(
                frame: .zero,
                params: candidate.webviewLayer.params,
                userAgent: userAgent,
                operation: nil,
                inAppId: candidate.inAppId,
                isPreloadMode: true
            )

            transparentView.loadHTMLFromCache(
                html: cachedHTML,
                baseUrl: candidate.webviewLayer.baseUrl
            )

            pool[candidate.inAppId] = PrerenderedWebView(
                transparentView: transparentView,
                webviewLayer: candidate.webviewLayer,
                inAppId: candidate.inAppId
            )

            Logger.common(
                message: "[WebView Prerender] Pre-rendering started for inAppId=\(candidate.inAppId) (pool size: \(pool.count)/\(maxPoolSize))",
                category: .webViewInAppMessages
            )
        }
    }

    func hasPrerendered(inAppId: String) -> Bool {
        pool[inAppId] != nil
    }

    func claim(inAppId: String) -> PrerenderedWebView? {
        guard let view = pool.removeValue(forKey: inAppId) else {
            Logger.common(
                message: "[WebView Prerender] Claim miss for inAppId=\(inAppId) (pool has: \(Array(pool.keys))), using standard flow",
                category: .webViewInAppMessages
            )
            return nil
        }

        Logger.common(
            message: "[WebView Prerender] Claimed pre-rendered view for inAppId=\(inAppId) (pool size: \(pool.count)/\(maxPoolSize))",
            category: .webViewInAppMessages
        )

        return view
    }

    func invalidate() {
        for (inAppId, view) in pool {
            view.transparentView.cleanUp()
            Logger.common(
                message: "[WebView Prerender] Invalidated pre-rendered view for inAppId=\(inAppId)",
                category: .webViewInAppMessages
            )
        }
        pool.removeAll()
    }

    // MARK: - Private

    @objc
    private func didReceiveMemoryWarning() {
        Logger.common(
            message: "[WebView Prerender] Memory warning received, evicting \(pool.count) pre-rendered view(s)",
            level: .default,
            category: .webViewInAppMessages
        )
        invalidate()
    }

    /// Selects up to `limit` candidates for pre-rendering.
    /// Priority in-apps come first, then the rest in config order.
    private func selectCandidates(
        from config: ConfigResponse,
        limit: Int
    ) -> [(inAppId: String, webviewLayer: WebviewContentBackgroundLayer)] {
        guard let inapps = config.inapps?.elements else { return [] }

        var priorityCandidates: [(inAppId: String, webviewLayer: WebviewContentBackgroundLayer)] = []
        var regularCandidates: [(inAppId: String, webviewLayer: WebviewContentBackgroundLayer)] = []

        for inapp in inapps {
            guard let variants = inapp.form.variants else { continue }
            for variant in variants {
                let layers: [ContentBackgroundLayerDTO]?
                switch variant {
                case .modal(let modal):
                    layers = modal.content?.background?.layers
                case .snackbar(let snackbar):
                    layers = snackbar.content?.background?.layers
                case .unknown:
                    layers = nil
                }

                guard let layers = layers else { continue }
                for layer in layers {
                    if case .webview(let webviewDTO) = layer,
                       let contentUrl = webviewDTO.contentUrl, !contentUrl.isEmpty,
                       let baseUrl = webviewDTO.baseUrl, !baseUrl.isEmpty {

                        let domainLayer = WebviewContentBackgroundLayer(
                            baseUrl: baseUrl,
                            contentUrl: contentUrl,
                            params: webviewDTO.params ?? [:]
                        )

                        let candidate = (inapp.id, domainLayer)

                        if inapp.isPriority {
                            priorityCandidates.append(candidate)
                        } else {
                            regularCandidates.append(candidate)
                        }
                    }
                }
            }
        }

        let allCandidates = priorityCandidates + regularCandidates
        return Array(allCandidates.prefix(limit))
    }

    private func createUserAgent() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknown"
        let appVersion = utilitiesFetcher.appVerson ?? "unknown"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknown"
        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }
}
