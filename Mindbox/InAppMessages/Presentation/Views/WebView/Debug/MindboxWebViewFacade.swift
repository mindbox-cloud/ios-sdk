//
//  MindboxWebViewFacade.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.01.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import WebKit

private enum PayloadKey {
    static let sdkVersion = "sdkVersion"
    static let sdkVersionNumeric = "sdkVersionNumeric"
    static let endpointId = "endpointId"
    static let deviceUuid = "deviceUUID"
    static let userVisitCount = "userVisitCount"

    static let inAppId = "inAppId"
    static let operationName = "operationName"
    static let operationBody = "operationBody"

    static let trackVisitSource = "trackVisitSource"
    static let trackVisitRequestUrl = "trackVisitRequestUrl"

    static let permissions = "permissions"

    enum Insets {
        static let key = "insets"
        static let top = "top"
        static let left = "left"
        static let bottom = "bottom"
        static let right = "right"
    }
}

@_spi(Internal)
public protocol InappWebViewFacadeProtocol: AnyObject {
    func makeView() -> UIView
    func loadHTML(baseUrl: String, contentUrl: String, onFailure: @escaping () -> Void)
    func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?)
    func cleanWebView()

    func sendReadyEvent(id: UUID)
    func sendToJS(_ message: BridgeMessage)
    func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void)
    func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?)
    func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?)
}

@_spi(Internal)
public protocol MindboxInternalWebViewFacadeProtocol: InappWebViewFacadeProtocol {
    func reloadWebView()
    func cleanWebView()

    /// Test-only hook used by internal test apps to observe raw incoming `WKScriptMessage` objects.
    ///
    /// This is meant purely for visual/debug purposes (e.g. to display the unparsed message payload),
    /// and must not be used by production code or relied upon as part of the SDK API contract.
    func setWKScriptMessageDelegate(_ delegate: WebBridgeWKScriptMessageDelegate?)
}

@_spi(Internal)
public typealias WebViewLog = (String) -> Void
@_spi(Internal)
public typealias WebViewLogError = (String) -> Void

@_spi(Internal)
public final class MindboxWebViewFacade: MindboxInternalWebViewFacadeProtocol {

    private let webView: WKWebView
    private let bridge: MindboxWebBridge
    private let params: [String: JSONValue]?
    private let operation: (name: String, body: String)?
    private let inAppId: String

    private let log: WebViewLog
    private let logError: WebViewLogError

    public init(params: [String: JSONValue]?,
                operation: (name: String, body: String)? = nil,
                userAgent: String,
                inAppId: String = "",
                log: @escaping WebViewLog = { _ in },
                logError: @escaping WebViewLogError = { _ in }) {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = userAgent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        // TODO: Turn on DEBUG IF after 2.15.0-RC
//        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
//        #endif
        let bridge = MindboxWebBridge(webView: webView)

        self.webView = webView
        self.bridge = bridge
        self.params = params
        self.operation = operation
        self.inAppId = inAppId
        self.log = log
        self.logError = logError
    }

    public func makeView() -> UIView {
        webView
    }
    
    public func loadHTML(baseUrl: String,
                         contentUrl: String,
                         onFailure: @escaping () -> Void) {
        let url = URL(string: baseUrl)
        let contentURL = URL(string: contentUrl)
        bridge.updateContentURL(contentURL)
        
        fetchHTML(from: contentUrl) { [weak webView] html in
            guard let webView else {
                DispatchQueue.main.async {
                    onFailure()
                }
                return
            }

            if let html {
                DispatchQueue.main.async {
                    webView.loadHTMLString(html, baseURL: url)
                }
            } else {
                DispatchQueue.main.async {
                    onFailure()
                }
            }
        }
    }
    
    public func reloadWebView() {
        DispatchQueue.main.async { [weak webView] in
            webView?.reload()
        }
    }
    
    public func cleanWebView() {
        DispatchQueue.main.async { [weak webView] in
            guard let webView else { return }
            webView.stopLoading()
        }
    }
    
    public func applyViewSettings(scrollViewDelegate: UIScrollViewDelegate?) {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.delegate = scrollViewDelegate
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    public func sendReadyEvent(id: UUID) {
        let message = BridgeMessage(
            type: .response,
            action: BridgeMessage.Action.ready,
            payload: buildStartPayload(),
            id: id
        )
        bridge.send(message)
    }
    
    public func sendToJS(_ message: BridgeMessage) {
        bridge.send(message)
    }

    public func evaluateJavaScript(_ script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        DispatchQueue.main.async { [weak webView] in
            guard let webView else {
                let error = MindboxError.internalError(
                    InternalError(
                        errorKey: .general,
                        reason: "WebView was deallocated before JavaScript execution"
                    )
                )
                completion(.failure(error))
                return
            }
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(result))
                }
            }
        }
    }
    
    public func setBridgeMessageDelegate(_ delegate: WebBridgeMessageDelegate?) {
        bridge.messageDelegate = delegate
    }
    
    public func setNavigationDelegate(_ delegate: WebBridgeNavigationDelegate?) {
        bridge.navigationDelegate = delegate
    }
    
    public func setWKScriptMessageDelegate(_ delegate: WebBridgeWKScriptMessageDelegate?) {
        bridge.delegate = delegate
    }
}

extension MindboxWebViewFacade {
    private func buildStartPayload() -> JSONValue {
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let systemInfoProvider = DI.injectOrFail(SystemInfoProvider.self)

        var mindboxParams: [String: Any] = [
            PayloadKey.sdkVersion: Mindbox.shared.sdkVersion,
            PayloadKey.endpointId: persistenceStorage.configuration?.endpoint ?? "",
            PayloadKey.deviceUuid: persistenceStorage.deviceUUID ?? "",
            PayloadKey.userVisitCount: "\(persistenceStorage.userVisitCount ?? 0)",
            PayloadKey.sdkVersionNumeric: "\(Constants.Versions.sdkVersionNumeric)",
            PayloadKey.inAppId: inAppId
        ]

        // Add system info (theme, platform, locale, version)
        let systemInfo = systemInfoProvider.getBasicSystemInfo()
        mindboxParams.merge(systemInfo) { _, new in new }

        // Add safe area insets
        let insets = systemInfoProvider.getSafeAreaInsets(from: webView)
        mindboxParams[PayloadKey.Insets.key] = [
            PayloadKey.Insets.top: insets.top,
            PayloadKey.Insets.left: insets.left,
            PayloadKey.Insets.bottom: insets.bottom,
            PayloadKey.Insets.right: insets.right
        ]

        // Add granted permissions
        let permissions = systemInfoProvider.getGrantedPermissions()
        if !permissions.isEmpty {
            var permissionsDict: [String: Any] = [:]
            for (key, status) in permissions {
                permissionsDict[key] = status.toDictionary()
            }
            mindboxParams[PayloadKey.permissions] = permissionsDict
        }

        // Merge params from configuration
        if let params, !params.isEmpty {
            for (key, value) in params {
                mindboxParams[key] = value.anyValue ?? NSNull()
            }
        }

        // Add operation data
        if let operation {
            mindboxParams[PayloadKey.operationName] = operation.name
            mindboxParams[PayloadKey.operationBody] = operation.body
        }

        // Add last track-visit data
        if let lastTrackVisit = SessionTemporaryStorage.shared.lastTrackVisit {
            if let source = lastTrackVisit.source {
                mindboxParams[PayloadKey.trackVisitSource] = source.rawValue
            }
            if let requestUrl = lastTrackVisit.requestUrl {
                mindboxParams[PayloadKey.trackVisitRequestUrl] = requestUrl
            }
        }

        // Serialize to JSON string
        do {
            let data = try JSONSerialization.data(withJSONObject: mindboxParams, options: [])
            guard let jsonString = String(bytes: data, encoding: .utf8) else {
                logError("[WebView] Failed to convert JSON data to UTF-8 string")
                return .string("{}")
            }
            return .string(jsonString)
        } catch {
            logError("[WebView] Failed to encode start payload to JSON string: \(error)")
            return .string("{}")
        }
    }
    
    private func fetchHTML(from urlString: String,
                           completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        
        let session = URLSession(configuration: config)
        
        log("Fetching HTML from \(url.absoluteString)")
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error {
                self?.logError("Error fetching HTML: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                self?.logError("Incorrect HTTP response")
                completion(nil)
                return
            }

            guard let data,
                  let htmlString = String(data: data, encoding: .utf8) else {
                self?.logError("Failed to decode HTML data")
                completion(nil)
                return
            }

            self?.log("HTML loaded successfully (\(htmlString.count) chars)")
            completion(htmlString)
        }

        task.resume()
    }
}
