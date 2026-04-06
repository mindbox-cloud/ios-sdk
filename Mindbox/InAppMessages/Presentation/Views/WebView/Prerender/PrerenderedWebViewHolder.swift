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

    private var prerenderedView: PrerenderedWebView?
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

    func prerender(from config: ConfigResponse) {
        guard let candidate = selectCandidate(from: config) else {
            Logger.common(
                message: "[WebView Prerender] No webview in-app candidate found for pre-rendering",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        guard let cachedHTML = preloader.cachedHTML(for: candidate.webviewLayer.contentUrl) else {
            Logger.common(
                message: "[WebView Prerender] HTML not yet cached for \(candidate.webviewLayer.contentUrl), skipping pre-render",
                level: .debug,
                category: .webViewInAppMessages
            )
            return
        }

        let userAgent = createUserAgent()
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

        self.prerenderedView = PrerenderedWebView(
            transparentView: transparentView,
            webviewLayer: candidate.webviewLayer,
            inAppId: candidate.inAppId
        )

        Logger.common(
            message: "[WebView Prerender] Pre-rendering started for inAppId=\(candidate.inAppId)",
            category: .webViewInAppMessages
        )
    }

    func hasPrerendered(inAppId: String) -> Bool {
        prerenderedView?.inAppId == inAppId
    }

    func claim(inAppId: String) -> PrerenderedWebView? {
        guard let view = prerenderedView, view.inAppId == inAppId else {
            Logger.common(
                message: "[WebView Prerender] Claim miss for inAppId=\(inAppId), using standard flow",
                category: .webViewInAppMessages
            )
            return nil
        }

        let claimed = prerenderedView
        prerenderedView = nil

        Logger.common(
            message: "[WebView Prerender] Claimed pre-rendered view for inAppId=\(inAppId)",
            category: .webViewInAppMessages
        )

        return claimed
    }

    func invalidate() {
        if let view = prerenderedView {
            view.transparentView.cleanUp()
            Logger.common(
                message: "[WebView Prerender] Invalidated pre-rendered view for inAppId=\(view.inAppId)",
                category: .webViewInAppMessages
            )
        }
        prerenderedView = nil
    }

    // MARK: - Private

    @objc
    private func didReceiveMemoryWarning() {
        invalidate()
    }

    /// Selects the best candidate for pre-rendering.
    /// Priority: first in-app with `isPriority == true` that has a webview layer;
    /// fallback: first in-app with a webview layer.
    private func selectCandidate(from config: ConfigResponse) -> (inAppId: String, webviewLayer: WebviewContentBackgroundLayer)? {
        guard let inapps = config.inapps?.elements else { return nil }

        var firstWebviewCandidate: (inAppId: String, webviewLayer: WebviewContentBackgroundLayer)?

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

                        if inapp.isPriority {
                            return (inapp.id, domainLayer)
                        }

                        if firstWebviewCandidate == nil {
                            firstWebviewCandidate = (inapp.id, domainLayer)
                        }
                    }
                }
            }
        }

        return firstWebviewCandidate
    }

    private func createUserAgent() -> String {
        let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknown"
        let appVersion = utilitiesFetcher.appVerson ?? "unknown"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknown"
        return "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
    }
}
