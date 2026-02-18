//
//  TransparentView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit
import MindboxLogger

final class TransparentView: UIView {

    weak var delegate: WebVCDelegate?
    weak var webViewAction: WebViewAction?

    private var facade: InappWebViewFacadeProtocol?
    private var quizInitTimeoutWorkItem: DispatchWorkItem?
    private var params: [String: JSONValue]?
    private var operation: (name: String, body: String)?
    private let userAgent: String
    private let inAppId: String
    private var lastReadyCheckedUrl: String?
    private var isReadyCheckInFlight = false

    init(frame: CGRect, params: [String: JSONValue], userAgent: String, operation: (name: String, body: String)?, inAppId: String) {
        self.params = params
        self.operation = operation
        self.userAgent = userAgent
        self.inAppId = inAppId
        super.init(frame: frame)
        commonInit()
    }

    override init(frame: CGRect) {
        self.params = nil
        self.operation = nil
        self.userAgent = ""
        self.inAppId = ""
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.params = nil
        self.operation = nil
        self.userAgent = ""
        self.inAppId = ""
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        Logger.common(message: "[WebView] Deinit TransparentView", category: .webViewInAppMessages)
    }

    private func commonInit() {
        createFacade()

        guard let view = facade?.makeView() else {
            return
        }
        addSubview(view)
        setupViewConstraints(view)

        facade?.applyViewSettings(scrollViewDelegate: self)
    }

    private func createFacade() {
        facade = MindboxWebViewFacade(params: params, operation: operation, userAgent: userAgent, inAppId: inAppId)
        facade?.setBridgeMessageDelegate(self)
        facade?.setNavigationDelegate(self)
    }

    func loadHTMLPage(baseUrl: String, contentUrl: String) {
        setupTimeoutTimer()

        facade?.loadHTML(baseUrl: baseUrl, contentUrl: contentUrl) { [weak self] in
            self?.quizInitTimeoutWorkItem?.cancel()
            self?.delegate?.closeTimeoutWebViewVC()
        }
    }

    func cleanUp() {
        facade?.cleanWebView()
    }

    private func setupTimeoutTimer() {
        let secondsTimeout = 7

        quizInitTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.delegate?.closeTimeoutWebViewVC()
        }
        quizInitTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(secondsTimeout), execute: workItem)
    }
}

// MARK: - Constraints setup
extension TransparentView {
    private func setupViewConstraints(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

extension TransparentView: WebBridgeMessageDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
        let action = message.action
        let data: String

        if case .string(let stringValue) = message.payload {
            data = stringValue
        } else if let payload = message.payload,
                  let payloadData = try? JSONEncoder().encode(payload),
                  let payloadString = String(data: payloadData, encoding: .utf8) {
            data = payloadString
        } else {
            data = ""
        }

        Logger.common(
            message: "[WebView] Bridge: received \(action) \(data)",
            category: .webViewInAppMessages
        )
        
        // TODO: - Create plugin-based handlers

        typealias Action = BridgeMessage.Action

        switch action {
        case Action.close:
            quizInitTimeoutWorkItem?.cancel()
            webViewAction?.onClose()
        case Action.`init`:
            quizInitTimeoutWorkItem?.cancel()
            webViewAction?.onInit()

        case Action.click:
            webViewAction?.onCompleted(data: data)

        case Action.hide:
            webViewAction?.onHide()

        case Action.log:
            webViewAction?.onLog(message: data)

        case Action.userAgent:
            Logger.common(
                message: "[WebView] UserAgent: \(data)",
                category: .webViewInAppMessages
            )

        case Action.ready:
            facade?.sendReadyEvent(id: message.id)

        case Action.asyncOperation:
            handleAsyncOperation(message: message)

        case Action.syncOperation:
            handleSyncOperation(message: message)

        default:
            Logger.common(
                message: "[WebView] Unknown action: \(action) with \(data)",
                category: .webViewInAppMessages
            )
        }
    }
}

// MARK: - WKNavigationDelegate

extension TransparentView: WebBridgeNavigationDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) {
        Logger.common(message: "[WebView] WKNavigationDelegate: start loading URL \(url?.absoluteString ?? "unknown")", category: .webViewInAppMessages)
        // Reset per-navigation checks (e.g. redirects / re-loads).
        lastReadyCheckedUrl = nil
        isReadyCheckInFlight = false
    }
    
    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        let urlString = url?.absoluteString ?? "unknown"
        Logger.common(message: "[WebView] WKNavigationDelegate: Upload completed \(urlString)", category: .webViewInAppMessages)

        // Avoid duplicate checks on multiple didFinish calls for the same URL.
        guard !isReadyCheckInFlight else { return }
        guard lastReadyCheckedUrl != urlString else { return }
        lastReadyCheckedUrl = urlString
        isReadyCheckInFlight = true

        let script = Constants.WebViewBridgeJS.receiveFromSDKReadyCheck
        facade?.evaluateJavaScript(script) { [weak self] result in
            guard let self else { return }
            self.isReadyCheckInFlight = false

            switch result {
            case .success(let anyValue):
                let hasReady = (anyValue as? Bool) ?? false
                Logger.common(
                    message: "[WebView] JS ready check for URL \(urlString): \(hasReady)",
                    category: .webViewInAppMessages
                )
                if !hasReady {
                    self.delegate?.closeJSReadyMissingWebViewVC(reason: "window.receiveFromSDK is missing for URL \(urlString)")
                }

            case .failure(let error):
                Logger.common(
                    message: "[WebView] JS ready check failed for URL \(urlString). Error: \(error.localizedDescription)",
                    category: .webViewInAppMessages
                )
                self.delegate?.closeJSReadyMissingWebViewVC(reason: "evaluateJavaScript error for URL \(urlString): \(error.localizedDescription)")
            }
        }
    }
    
    func webBridge(_ bridge: MindboxWebBridge, didFailProvisionalNavigation url: URL?, error: any Error) {
        Logger.common(message: "[WebView] WKNavigationDelegate: Loading error \(error.localizedDescription)", category: .webViewInAppMessages)
    }
    
    func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = url {
            Logger.common(message: "[WebView] WKNavigationDelegate: Navigating by URL \(url.absoluteString)", category: .webViewInAppMessages)
        }
        decisionHandler(.allow)
    }
}

// MARK: - Operation Handlers

extension TransparentView {

    private func extractOperationParams(from message: BridgeMessage) -> (name: String, body: String)? {
        guard case .string(let str) = message.payload,
              let data = str.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data),
              case .string(let operation) = dict["operation"],
              let body = dict["body"],
              let bodyData = try? JSONEncoder().encode(body),
              let bodyString = String(data: bodyData, encoding: .utf8) else {
            return nil
        }

        return (operation, bodyString)
    }

    private func sendBridgeError(_ errorMessage: String, action: String, id: UUID) {
        let errorPayload: JSONValue = .object(["error": .string(errorMessage)])
        let response = BridgeMessage(type: .error, action: action, payload: errorPayload, id: id)
        facade?.sendToJS(response)
    }

    private func handleAsyncOperation(message: BridgeMessage) {
        guard let params = extractOperationParams(from: message) else {
            sendBridgeError("Invalid payload: missing or empty operation", action: message.action, id: message.id)
            return
        }

        let customEvent = CustomEvent(name: params.name, payload: params.body)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)

        let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        do {
            try databaseRepository.create(event: event)
            Logger.common(message: "[WebView] asyncOperation '\(params.name)' queued", level: .info, category: .webViewInAppMessages)
        } catch {
            Logger.common(message: "[WebView] asyncOperation '\(params.name)' failed: \(error)", level: .error, category: .webViewInAppMessages)
            sendBridgeError("Failed to queue operation: \(error.localizedDescription)", action: message.action, id: message.id)
            return
        }

        let successResponse = BridgeMessage(
            type: .response,
            action: message.action,
            payload: .object(["success": .bool(true)]),
            id: message.id
        )
        facade?.sendToJS(successResponse)
    }

    private func handleSyncOperation(message: BridgeMessage) {
        guard let params = extractOperationParams(from: message) else {
            sendBridgeError("Invalid payload: missing or empty operation", action: message.action, id: message.id)
            return
        }

        let customEvent = CustomEvent(name: params.name, payload: params.body)
        let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
        let eventRepository = DI.injectOrFail(EventRepository.self)

        Logger.common(message: "[WebView] syncOperation '\(params.name)' sending", level: .info, category: .webViewInAppMessages)

        eventRepository.send(type: OperationResponse.self, event: event) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    Logger.common(message: "[WebView] syncOperation '\(params.name)' success", level: .info, category: .webViewInAppMessages)
                    let responseJSON = response.createJSON()
                    let successResponse = BridgeMessage(
                        type: .response,
                        action: message.action,
                        payload: .string(responseJSON),
                        id: message.id
                    )
                    self?.facade?.sendToJS(successResponse)

                case .failure(let error):
                    Logger.common(message: "[WebView] syncOperation '\(params.name)' failed: \(error)", level: .error, category: .webViewInAppMessages)
                    let errorJSON = error.createJSON()
                    let errorResponse = BridgeMessage(
                        type: .error,
                        action: message.action,
                        payload: .string(errorJSON),
                        id: message.id
                    )
                    self?.facade?.sendToJS(errorResponse)
                }
            }
        }
    }
}

extension TransparentView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}

protocol WebViewAction: AnyObject {
    func onInit()
    func onCompleted(data: String)
    func onClose()
    func onHide()
    func onLog(message: String)
}
