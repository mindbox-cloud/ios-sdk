//
//  TransparentView.swift
//  Mindbox
//
//  Created by vailence on 17.10.2024.
//

import UIKit
import WebKit
import SafariServices
import MindboxLogger

// swiftlint:disable file_length
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
    private lazy var localStateStorage: WebViewLocalStateStorageProtocol = DI.injectOrFail(WebViewLocalStateStorageProtocol.self)
    private lazy var permissionHandlerRegistry = DI.injectOrFail(PermissionHandlerRegistry.self)

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
            self?.delegate?.closeLoadFailedWebViewVC(
                reason: "[WebView] Failed to load HTML content from baseUrl=\(baseUrl), contentUrl=\(contentUrl)"
            )
        }
    }

    func cleanUp() {
        facade?.cleanWebView()
    }

    private func setupTimeoutTimer() {
        quizInitTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.delegate?.closeTimeoutWebViewVC()
        }
        quizInitTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Constants.WebView.timeoutSeconds), execute: workItem)
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

        case Action.openLink:
            handleNavigate(message: message)

        case Action.localStateGet:
            handleLocalStateGet(message: message)

        case Action.localStateSet:
            handleLocalStateSet(message: message)

        case Action.localStateInit:
            handleLocalStateInit(message: message)

        case Action.permissionRequest:
            handlePermissionRequest(message: message)

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

        let script = Constants.WebViewBridgeJS.bridgeFunctionReadyCheck
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
                    self.delegate?.closeJSReadyMissingWebViewVC(reason: "window.bridgeMessagesHandlers.emit is missing for URL \(urlString)")
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
        delegate?.closeLoadFailedWebViewVC(
            reason: "[WebView] WKNavigation loading failed for URL \(url?.absoluteString ?? "unknown"): \(error.localizedDescription)"
        )
    }
    
    func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, navigationType: WKNavigationType, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let urlString = url?.absoluteString ?? "unknown"

        switch navigationType {
        case .other, .reload, .backForward:
            Logger.common(
                message: "[WebView] WKNavigationDelegate: allowing navigation (\(navigationType.debugLabel)) to URL \(urlString)",
                category: .webViewInAppMessages
            )
            decisionHandler(.allow)

        case .linkActivated, .formSubmitted, .formResubmitted:
            Logger.common(
                message: "[WebView] WKNavigationDelegate: blocking navigation (\(navigationType.debugLabel)) to URL \(urlString). Forwarding to JS.",
                category: .webViewInAppMessages
            )
            decisionHandler(.cancel)

            if let url = url {
                let payload: JSONValue = .object(["url": .string(url.absoluteString)])
                let event = BridgeMessage(
                    type: .request,
                    action: BridgeMessage.Action.navigationIntercepted,
                    payload: payload
                )
                facade?.sendToJS(event)
            }

        @unknown default:
            Logger.common(
                message: "[WebView] WKNavigationDelegate: blocking unknown navigation type (\(navigationType.rawValue)) to URL \(urlString)",
                category: .webViewInAppMessages
            )
            decisionHandler(.cancel)
        }
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

// MARK: - LocalState Handlers

extension TransparentView {

    private func handleLocalStateGet(message: BridgeMessage) {
        guard let payload = extractLocalStatePayload(from: message) else {
            sendBridgeError("Invalid payload", action: message.action, id: message.id)
            return
        }

        let keys: [String]
        if case .array(let arr) = payload["data"] {
            keys = arr.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        } else {
            keys = []
        }

        let storage = localStateStorage
        let state = storage.get(keys: keys)

        Logger.common(
            message: "[WebView] localState.get keys=\(keys) → \(state.data.count) entries, version=\(state.version)",
            level: .info,
            category: .webViewInAppMessages
        )

        // Build response data: found keys → value, missing keys → null
        var dataObject: [String: JSONValue] = [:]
        if keys.isEmpty {
            for (key, value) in state.data {
                dataObject[key] = .string(value)
            }
        } else {
            for key in keys {
                if let value = state.data[key] {
                    dataObject[key] = .string(value)
                } else {
                    dataObject[key] = .null
                }
            }
        }

        let responsePayload: JSONValue = .object([
            "data": .object(dataObject),
            "version": .int(state.version)
        ])

        let response = BridgeMessage(
            type: .response,
            action: message.action,
            payload: responsePayload,
            id: message.id
        )
        facade?.sendToJS(response)
    }

    private func handleLocalStateSet(message: BridgeMessage) {
        guard let payload = extractLocalStatePayload(from: message),
              case .object(let dataDict) = payload["data"] else {
            sendBridgeError("Invalid payload: missing 'data' object", action: message.action, id: message.id)
            return
        }

        var data: [String: String?] = [:]
        for (key, value) in dataDict {
            switch value {
            case .string(let s):
                data[key] = s
            case .null:
                data[key] = nil as String?
            default:
                if let encoded = try? JSONEncoder().encode(value),
                   let str = String(data: encoded, encoding: .utf8) {
                    data[key] = str
                }
            }
        }

        let storage = localStateStorage
        let state = storage.set(data: data)

        Logger.common(
            message: "[WebView] localState.set \(data.count) keys → version=\(state.version)",
            level: .info,
            category: .webViewInAppMessages
        )

        let response = BridgeMessage(
            type: .response,
            action: message.action,
            payload: localStateToPayload(data: data, version: state.version),
            id: message.id
        )
        facade?.sendToJS(response)
    }

    private func handleLocalStateInit(message: BridgeMessage) {
        guard let payload = extractLocalStatePayload(from: message),
              case .int(let version) = payload["version"],
              case .object(let dataDict) = payload["data"] else {
            sendBridgeError("Invalid payload: missing 'version' or 'data'", action: message.action, id: message.id)
            return
        }

        var data: [String: String?] = [:]
        for (key, value) in dataDict {
            switch value {
            case .string(let s):
                data[key] = s
            case .null:
                data[key] = nil as String?
            default:
                if let encoded = try? JSONEncoder().encode(value),
                   let str = String(data: encoded, encoding: .utf8) {
                    data[key] = str
                }
            }
        }

        let storage = localStateStorage
        guard let state = storage.initialize(version: version, data: data) else {
            sendBridgeError(
                "Version must be a positive integer, got \(version)",
                action: message.action,
                id: message.id
            )
            return
        }

        Logger.common(
            message: "[WebView] localState.init version=\(version), \(data.count) keys",
            level: .info,
            category: .webViewInAppMessages
        )

        let response = BridgeMessage(
            type: .response,
            action: message.action,
            payload: localStateToPayload(data: data, version: state.version),
            id: message.id
        )
        facade?.sendToJS(response)
    }

    // MARK: - LocalState Helpers

    private func extractLocalStatePayload(from message: BridgeMessage) -> [String: JSONValue]? {
        // Payload arrives as a JSON string: "{\"data\":{...},\"version\":3}"
        if case .string(let str) = message.payload,
           let data = str.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            return dict
        }
        // Payload is already a decoded object
        if case .object(let dict) = message.payload {
            return dict
        }
        return nil
    }

    private func localStateToPayload(data: [String: String?], version: Int) -> JSONValue {
        var dataObject: [String: JSONValue] = [:]
        for (key, value) in data {
            dataObject[key] = value.map { .string($0) } ?? .null
        }
        return .object([
            "data": .object(dataObject),
            "version": .int(version)
        ])
    }
}

// MARK: - Navigate Handler

extension TransparentView {

    private func handleNavigate(message: BridgeMessage) {
        guard let urlString = extractNavigateURL(from: message) else {
            sendBridgeError("Invalid payload: missing or empty 'url' field", action: message.action, id: message.id)
            return
        }

        guard let url = URL(string: urlString) else {
            sendBridgeError("Invalid URL: '\(urlString)' could not be parsed", action: message.action, id: message.id)
            return
        }

        let scheme = url.scheme?.lowercased()

        if scheme == "http" || scheme == "https" {
            Logger.common(
                message: "[WebView] navigate: trying universal link first for \(urlString)",
                level: .info,
                category: .webViewInAppMessages
            )
            openAsUniversalLinkOrSafari(url: url, message: message)
        } else {
            Logger.common(
                message: "[WebView] navigate: opening via UIApplication \(urlString)",
                level: .info,
                category: .webViewInAppMessages
            )
            openViaUIApplication(url: url, message: message)
        }
    }

    private func openAsUniversalLinkOrSafari(url: URL, message: BridgeMessage) {
        DispatchQueue.main.async { [weak self] in
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
                DispatchQueue.main.async {
                    if opened {
                        Logger.common(
                            message: "[WebView] navigate: opened as universal link \(url.absoluteString)",
                            level: .info,
                            category: .webViewInAppMessages
                        )
                        let response = BridgeMessage(
                            type: .response,
                            action: message.action,
                            payload: .object(["success": .bool(true)]),
                            id: message.id
                        )
                        self?.facade?.sendToJS(response)
                    } else {
                        Logger.common(
                            message: "[WebView] navigate: not a universal link, falling back to SFSafariViewController for \(url.absoluteString)",
                            level: .info,
                            category: .webViewInAppMessages
                        )
                        self?.openInSafariViewController(url: url, message: message)
                    }
                }
            }
        }
    }

    private func openInSafariViewController(url: URL, message: BridgeMessage) {
        guard let presentingVC = delegate as? UIViewController else {
            Logger.common(
                message: "[WebView] navigate: no presenting view controller found",
                level: .default,
                category: .webViewInAppMessages
            )
            sendBridgeError("Failed to open URL: no presenting view controller", action: message.action, id: message.id)
            return
        }

        let safariVC = SFSafariViewController(url: url)
        presentingVC.present(safariVC, animated: true) { [weak self] in
            Logger.common(
                message: "[WebView] navigate: SFSafariViewController presented for \(url.absoluteString)",
                level: .info,
                category: .webViewInAppMessages
            )
            let response = BridgeMessage(
                type: .response,
                action: message.action,
                payload: .object(["success": .bool(true)]),
                id: message.id
            )
            self?.facade?.sendToJS(response)
        }
    }

    private func openViaUIApplication(url: URL, message: BridgeMessage) {
        DispatchQueue.main.async { [weak self] in
            UIApplication.shared.open(url, options: [:]) { success in
                DispatchQueue.main.async {
                    if success {
                        Logger.common(
                            message: "[WebView] navigate: successfully opened \(url.absoluteString)",
                            level: .info,
                            category: .webViewInAppMessages
                        )
                        let response = BridgeMessage(
                            type: .response,
                            action: message.action,
                            payload: .object(["success": .bool(true)]),
                            id: message.id
                        )
                        self?.facade?.sendToJS(response)
                    } else {
                        Logger.common(
                            message: "[WebView] navigate: failed to open \(url.absoluteString)",
                            level: .default,
                            category: .webViewInAppMessages
                        )
                        self?.sendBridgeError("Failed to open URL: '\(url.absoluteString)'", action: message.action, id: message.id)
                    }
                }
            }
        }
    }

    private func extractNavigateURL(from message: BridgeMessage) -> String? {
        guard case .string(let str) = message.payload,
              let data = str.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data),
              case .string(let urlString) = dict["url"],
              !urlString.isEmpty else {
            return nil
        }
        return urlString
    }
}

// MARK: - Permission Request Handler

extension TransparentView {

    private func handlePermissionRequest(message: BridgeMessage) {
        guard let typeString = extractPermissionType(from: message) else {
            sendBridgeError("Invalid payload: missing or empty 'type' field", action: message.action, id: message.id)
            return
        }

        guard let permissionType = PermissionType(rawValue: typeString) else {
            sendBridgeError("Unknown permission type: '\(typeString)'", action: message.action, id: message.id)
            return
        }

        guard let handler = permissionHandlerRegistry.handler(for: permissionType) else {
            sendBridgeError("No handler registered for permission type: '\(typeString)'", action: message.action, id: message.id)
            return
        }

        for key in handler.requiredInfoPlistKeys {
            guard Bundle.main.object(forInfoDictionaryKey: key) != nil else {
                sendBridgeError("Missing Info.plist key: \(key)", action: message.action, id: message.id)
                return
            }
        }

        handler.request { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .granted:
                    let response = BridgeMessage(
                        type: .response,
                        action: message.action,
                        payload: .object(["result": .string("granted")]),
                        id: message.id
                    )
                    self.facade?.sendToJS(response)

                case .denied:
                    let response = BridgeMessage(
                        type: .response,
                        action: message.action,
                        payload: .object(["result": .string("denied")]),
                        id: message.id
                    )
                    self.facade?.sendToJS(response)

                case .error(let errorMessage):
                    self.sendBridgeError(errorMessage, action: message.action, id: message.id)
                }
            }
        }
    }

    private func extractPermissionType(from message: BridgeMessage) -> String? {
        guard case .string(let str) = message.payload,
              let data = str.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data),
              case .string(let typeString) = dict["type"],
              !typeString.isEmpty else {
            return nil
        }
        return typeString
    }
}

// MARK: - WKNavigationType Debug Label

private extension WKNavigationType {
    var debugLabel: String {
        switch self {
        case .linkActivated:    return "linkActivated"
        case .formSubmitted:    return "formSubmitted"
        case .backForward:      return "backForward"
        case .reload:           return "reload"
        case .formResubmitted:  return "formResubmitted"
        case .other:            return "other"
        @unknown default:       return "unknown(\(rawValue))"
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
