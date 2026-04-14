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

/// Pre-renders up to `maxPreRenderedCount` webview in-apps simultaneously by completing the JS
/// handshake immediately with real data.
///
/// Instead of holding the `ready` handshake until trigger (warm approach), this holder sends
/// the payload right away — JS renders the full in-app content including images/fonts.
/// When the in-app triggers, the fully rendered WebView is returned and shown instantly.
///
/// **Result**: True offline support — all resources are loaded during pre-render while online.
/// After a view is claimed, the holder immediately starts pre-rendering a replacement.
final class WarmWebViewHolder: WarmWebViewHolderProtocol {

    private static let maxPreRenderedCount = 2

    /// Pre-rendered views keyed by inAppId.
    private var preRenderedViews: [String: TransparentView] = [:]

    /// Off-screen windows keyed by inAppId — keeps each WKWebView in the hierarchy so
    /// the WebContent process completes layout, image decode, and JS execution.
    private var offscreenWindows: [String: UIWindow] = [:]

    private var lastConfig: ConfigResponse?
    private let preloader: WebViewContentPreloaderProtocol
    private let persistenceStorage: PersistenceStorage

    init(preloader: WebViewContentPreloaderProtocol, persistenceStorage: PersistenceStorage) {
        self.preloader = preloader
        self.persistenceStorage = persistenceStorage
        persistenceStorage.isStoriesPrepared = false
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
        lastConfig = config

        let candidates = findWebViewCandidates(from: config, limit: Self.maxPreRenderedCount)
        guard !candidates.isEmpty else {
            Logger.common(
                message: "[PreRender] No webview in-app candidates found in config",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        for candidate in candidates {
            guard preRenderedViews.count < Self.maxPreRenderedCount else { break }
            guard preRenderedViews[candidate.inAppId] == nil else {
                Logger.common(
                    message: "[PreRender] Already pre-rendering inAppId=\(candidate.inAppId), skipping",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                continue
            }
            guard let html = preloader.cachedHTML(for: candidate.contentUrl) else {
                Logger.common(
                    message: "[PreRender] HTML not yet cached for \(candidate.contentUrl), skipping",
                    level: .debug,
                    category: .webViewInAppMessages
                )
                continue
            }

            let trackerId = WebViewLoadingTracker.makeId(inAppId: candidate.inAppId, flow: "prerender")
            WebViewLoadingTracker.begin(id: trackerId, stage: "prerender_start")

            createPreRenderedView(
                html: html,
                baseUrl: candidate.baseUrl,
                inAppId: candidate.inAppId,
                params: candidate.params,
                trackerId: trackerId
            )
        }
    }

    func claim(inAppId: String, params: [String: JSONValue], operation: (name: String, body: String)?) -> TransparentView? {
        guard let view = preRenderedViews[inAppId] else {
            Logger.common(
                message: "[PreRender] Claim miss — no pre-rendered view for inAppId=\(inAppId)",
                category: .webViewInAppMessages
            )
            return nil
        }

        guard view.isFullyRendered else {
            Logger.common(
                message: "[PreRender] Claim miss — view not yet fully rendered for inAppId=\(inAppId)",
                category: .webViewInAppMessages
            )
            return nil
        }

        // Detach from off-screen window before transferring to the real view hierarchy
        view.removeFromSuperview()
        offscreenWindows.removeValue(forKey: inAppId)
        preRenderedViews.removeValue(forKey: inAppId)

        let anyFullyRendered = preRenderedViews.values.contains { $0.isFullyRendered }
        persistenceStorage.isStoriesPrepared = anyFullyRendered

        WebViewLoadingTracker.checkpoint(id: view.performanceTrackerId, stage: "view_claimed")
        Logger.common(
            message: "[PreRender] Claimed fully rendered view for inAppId=\(inAppId). Remaining: \(preRenderedViews.count)",
            category: .webViewInAppMessages
        )

        scheduleNextPreRender()

        return view
    }

    func invalidate() {
        guard !preRenderedViews.isEmpty else { return }
        for (_, view) in preRenderedViews {
            view.removeFromSuperview()
            view.cleanUp()
        }
        preRenderedViews.removeAll()
        offscreenWindows.removeAll()
        persistenceStorage.isStoriesPrepared = false
        Logger.common(
            message: "[PreRender] Invalidated all pre-rendered views",
            category: .webViewInAppMessages
        )
    }

    // MARK: - Private

    @objc
    private func didReceiveMemoryWarning() {
        Logger.common(
            message: "[PreRender] Memory warning received, evicting all pre-rendered views",
            level: .default,
            category: .webViewInAppMessages
        )
        invalidate()
    }

    private func createPreRenderedView(html: String, baseUrl: String, inAppId: String, params: [String: JSONValue], trackerId: String) {
        let userAgent = createUserAgent()
        let startTime = CFAbsoluteTimeGetCurrent()

        let screenBounds = UIScreen.main.bounds
        let view = TransparentView(
            frame: screenBounds,
            params: params,
            userAgent: userAgent,
            operation: nil,
            inAppId: inAppId,
            isPreRenderMode: true
        )
        view.performanceTrackerId = trackerId

        // Attach to an off-screen window so WKWebView completes rendering
        let window = UIWindow(frame: screenBounds)
        window.windowLevel = .init(rawValue: -1)
        window.alpha = 0.0
        window.isUserInteractionEnabled = false
        window.isHidden = false
        window.addSubview(view)
        view.frame = window.bounds
        offscreenWindows[inAppId] = window

        view.onPreRenderComplete = { [weak self] in
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let ms = Int(elapsed * 1000)
            Logger.common(
                message: "[PreRender] Fully rendered in \(ms)ms for inAppId=\(inAppId)",
                category: .webViewInAppMessages
            )
            self?.persistenceStorage.isStoriesPrepared = true
        }

        view.loadHTMLFromCache(html: html, baseUrl: baseUrl)
        WebViewLoadingTracker.checkpoint(id: trackerId, stage: "html_sent_to_webview")
        preRenderedViews[inAppId] = view

        Logger.common(
            message: "[PreRender] Started pre-render for inAppId=\(inAppId). Total: \(preRenderedViews.count)/\(Self.maxPreRenderedCount)",
            category: .webViewInAppMessages
        )
    }

    private func scheduleNextPreRender() {
        guard let config = lastConfig else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            guard self.preRenderedViews.count < Self.maxPreRenderedCount else { return }
            self.warmUp(from: config)
            Logger.common(
                message: "[PreRender] Re-render triggered after claim",
                category: .webViewInAppMessages
            )
        }
    }

    private struct WebViewCandidate {
        let baseUrl: String
        let contentUrl: String
        let inAppId: String
        let params: [String: JSONValue]
    }

    private func findWebViewCandidates(from config: ConfigResponse, limit: Int) -> [WebViewCandidate] {
        var result: [WebViewCandidate] = []
        guard let inapps = config.inapps?.elements else { return result }

        for inapp in inapps {
            guard result.count < limit else { break }
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
                        result.append(WebViewCandidate(
                            baseUrl: baseUrl,
                            contentUrl: contentUrl,
                            inAppId: inapp.id,
                            params: webviewDTO.params ?? [:]
                        ))
                    }
                }
            }
        }

        return result
    }

    private func createUserAgent() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknown"
        let appVersion = utilitiesFetcher.appVerson ?? "unknown"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknown"
        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }
}
