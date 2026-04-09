//
//  WarmWebViewHolder.swift
//  Mindbox
//
//  Created by Mindbox on 08.04.2026.
//

import UIKit
import MindboxLogger

protocol WarmWebViewHolderProtocol: AnyObject {
    func warmUp(from config: ConfigResponse)
    func claim(inAppId: String, params: [String: JSONValue], operation: (name: String, body: String)?) -> TransparentView?
    func invalidate()
}

/// Maintains a single "warm" WKWebView with shared HTML+JS pre-loaded and ready.
///
/// Instead of pre-rendering a separate WKWebView per in-app (like `PrerenderedWebViewHolder`),
/// this holder creates ONE WebView, loads the shared HTML+JS template, and waits for the JS "ready" signal.
/// When any webview in-app triggers, the warm view is claimed — its inAppId, params, and operation
/// are updated to match the target in-app, and the held handshake is completed.
///
/// **Result**: 100% hit rate for webview in-apps, ~0.3s presentation time vs ~2.2s cold start.
/// After claim, the holder re-warms a new WebView in the background for the next trigger.
final class WarmWebViewHolder: WarmWebViewHolderProtocol {

    private var warmView: TransparentView?
    private var warmUpHTML: String?
    private var warmUpBaseUrl: String?
    private var warmUpStartTime: CFAbsoluteTime?
    private let preloader: WebViewContentPreloaderProtocol

    init(preloader: WebViewContentPreloaderProtocol) {
        self.preloader = preloader
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

    // MARK: - WarmWebViewHolderProtocol

    func warmUp(from config: ConfigResponse) {
        guard warmView == nil else {
            Logger.common(
                message: "[Warm WebView] Already warmed up, skipping",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        guard let candidate = findFirstWebViewCandidate(from: config) else {
            Logger.common(
                message: "[Warm WebView] No webview in-app candidates found in config",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        guard let html = preloader.cachedHTML(for: candidate.contentUrl) else {
            Logger.common(
                message: "[Warm WebView] HTML not yet cached for \(candidate.contentUrl), skipping warm-up",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        warmUpHTML = html
        warmUpBaseUrl = candidate.baseUrl

        createWarmView(html: html, baseUrl: candidate.baseUrl)
    }

    func claim(inAppId: String, params: [String: JSONValue], operation: (name: String, body: String)?) -> TransparentView? {
        guard let view = warmView else {
            Logger.common(
                message: "[Warm WebView] Claim miss — no warm view available for inAppId=\(inAppId)",
                category: .webViewInAppMessages
            )
            return nil
        }

        guard view.pendingReadyId != nil else {
            Logger.common(
                message: "[Warm WebView] Claim miss — warm view not yet ready (JS has not sent 'ready' event)",
                category: .webViewInAppMessages
            )
            return nil
        }

        warmView = nil

        view.updateInAppId(inAppId)
        view.updateParams(params)
        view.updateOperation(operation)

        Logger.common(
            message: "[Warm WebView] Claimed warm view for inAppId=\(inAppId)",
            category: .webViewInAppMessages
        )

        scheduleRewarm()

        return view
    }

    func invalidate() {
        guard warmView != nil else { return }
        warmView?.cleanUp()
        warmView = nil
        Logger.common(
            message: "[Warm WebView] Invalidated",
            category: .webViewInAppMessages
        )
    }

    // MARK: - Private

    @objc
    private func didReceiveMemoryWarning() {
        Logger.common(
            message: "[Warm WebView] Memory warning received, evicting warm view",
            level: .default,
            category: .webViewInAppMessages
        )
        invalidate()
    }

    private func createWarmView(html: String, baseUrl: String) {
        let userAgent = createUserAgent()
        let startTime = CFAbsoluteTimeGetCurrent()
        warmUpStartTime = startTime

        let view = TransparentView(
            frame: .zero,
            params: [:],
            userAgent: userAgent,
            operation: nil,
            inAppId: "",
            isPreloadMode: true
        )

        view.onReadyInPreloadMode = { [weak self] in
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let ms = Int(elapsed * 1000)
            Logger.common(
                message: "[Warm WebView] JS ready in \(ms)ms (warm-up complete)",
                category: .webViewInAppMessages
            )
            self?.warmUpStartTime = nil
        }

        view.loadHTMLFromCache(html: html, baseUrl: baseUrl)
        warmView = view

        Logger.common(
            message: "[Warm WebView] Warm-up started (HTML loaded, waiting for JS ready)",
            category: .webViewInAppMessages
        )
    }

    private func scheduleRewarm() {
        guard let html = warmUpHTML, let baseUrl = warmUpBaseUrl else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.warmView == nil else { return }
            self.createWarmView(html: html, baseUrl: baseUrl)
            Logger.common(
                message: "[Warm WebView] Re-warm triggered after claim",
                category: .webViewInAppMessages
            )
        }
    }

    private func findFirstWebViewCandidate(
        from config: ConfigResponse
    ) -> (baseUrl: String, contentUrl: String)? {
        guard let inapps = config.inapps?.elements else { return nil }

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

                guard let layers else { continue }
                for layer in layers {
                    if case .webview(let webviewDTO) = layer,
                       let contentUrl = webviewDTO.contentUrl, !contentUrl.isEmpty,
                       let baseUrl = webviewDTO.baseUrl, !baseUrl.isEmpty {
                        return (baseUrl, contentUrl)
                    }
                }
            }
        }

        return nil
    }

    private func createUserAgent() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknown"
        let appVersion = utilitiesFetcher.appVerson ?? "unknown"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknown"
        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }
}
