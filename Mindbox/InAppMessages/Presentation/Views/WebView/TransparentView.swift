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
    private lazy var permissionHandlerRegistry = DI.injectOrFail(PermissionHandlerRegistryProtocol.self)
    private lazy var hapticService: HapticServiceProtocol = DI.injectOrFail(HapticServiceProtocol.self)
    private var isMotionServiceInitialized = false
    private lazy var motionService: MotionServiceProtocol = {
        isMotionServiceInitialized = true
        let service = DI.injectOrFail(MotionServiceProtocol.self)
        service.onGestureDetected = { [weak self] gesture, data in
            self?.sendMotionEvent(gesture: gesture, data: data)
        }
        return service
    }()

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
        if isMotionServiceInitialized { motionService.stopMonitoring() }
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

    func cancelTimeoutTimer() {
        quizInitTimeoutWorkItem?.cancel()
        quizInitTimeoutWorkItem = nil
    }

    func restartTimeoutTimer() {
        setupTimeoutTimer()
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

        guard let parsedAction = BridgeMessage.Action(rawValue: action) else {
            Logger.common(
                message: "[WebView] Unknown action: \(action) with \(data)",
                category: .webViewInAppMessages
            )
            return
        }

        switch parsedAction {

        // Lifecycle
        case .close:
            quizInitTimeoutWorkItem?.cancel()
            hapticService.stopPattern()
            if isMotionServiceInitialized { motionService.stopMonitoring() }
            webViewAction?.onClose()
        case .`init`:
            quizInitTimeoutWorkItem?.cancel()
            hapticService.prepare()
            webViewAction?.onInit()
        case .click:
            webViewAction?.onCompleted(data: data)
        case .hide:
            webViewAction?.onHide()
        case .ready:
            facade?.sendReadyEvent(id: message.id)

        // Info
        case .log:
            webViewAction?.onLog(message: data)

        // Operations
        case .asyncOperation:
            handleAsyncOperation(message: message)
        case .syncOperation:
            handleSyncOperation(message: message)

        // Navigation, Settings & Permissions
        case .openLink:
            handleNavigate(message: message)
        case .settingsOpen:
            handleOpenSettings(message: message)
        case .permissionRequest:
            handlePermissionRequest(message: message)

        // Local State
        case .localStateGet:
            handleLocalStateGet(message: message)
        case .localStateSet:
            handleLocalStateSet(message: message)
        case .localStateInit:
            handleLocalStateInit(message: message)

        // Haptic
        case .haptic:
            handleHaptic(message: message)

        // Motion
        case .motionStart:
            handleMotionStart(message: message)
        case .motionStop:
            handleMotionStop(message: message)

        // Native → JS (not handled here)
        case .navigationIntercepted, .motionEvent:
            break
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

    private func sendBridgeSuccess(action: String, id: UUID) {
        let response = BridgeMessage(
            type: .response,
            action: action,
            payload: .object(["success": .bool(true)]),
            id: id
        )
        facade?.sendToJS(response)
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

        sendBridgeSuccess(action: message.action, id: message.id)
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

        // HTTP 2xx → forward the raw body to JS as a Response so the JS Tracker
        // can dispatch onSuccess / onValidationError by the body's `status`.
        // 4xx, 5xx and network failures stay on the MindboxError → Error path.
        eventRepository.sendRaw(event: event) { [weak self] result in
            DispatchQueue.main.async {
                let outgoing = TransparentView.makeSyncOperationResponse(
                    result: result,
                    action: message.action,
                    id: message.id
                )
                switch outgoing.type {
                case .response:
                    Logger.common(message: "[WebView] syncOperation '\(params.name)' success", level: .info, category: .webViewInAppMessages)
                case .error:
                    if case .failure(let error) = result {
                        Logger.common(message: "[WebView] syncOperation '\(params.name)' failed: \(error)", level: .error, category: .webViewInAppMessages)
                    } else {
                        Logger.common(message: "[WebView] syncOperation '\(params.name)' failed: non-UTF-8 response body", level: .error, category: .webViewInAppMessages)
                    }
                default:
                    break
                }
                self?.facade?.sendToJS(outgoing)
            }
        }
    }

    /// Maps the raw `sendRaw` result of a `syncOperation` request to the outgoing
    /// `BridgeMessage` sent back to JS. Pure function — no side effects — extracted
    /// to keep the JS-bridge contract independently unit-testable.
    static func makeSyncOperationResponse(
        result: Result<Data, MindboxError>,
        action: String,
        id: UUID
    ) -> BridgeMessage {
        switch result {
        case .success(let data):
            guard let bodyString = String(data: data, encoding: .utf8) else {
                return BridgeMessage(
                    type: .error,
                    action: action,
                    payload: .object(["error": .string("Response body is not valid UTF-8")]),
                    id: id
                )
            }
            return BridgeMessage(
                type: .response,
                action: action,
                payload: .string(bodyString),
                id: id
            )
        case .failure(let error):
            return BridgeMessage(
                type: .error,
                action: action,
                payload: .string(error.createJSON()),
                id: id
            )
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
                        self?.sendBridgeSuccess(action: message.action, id: message.id)
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
            self?.sendBridgeSuccess(action: message.action, id: message.id)
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
                        self?.sendBridgeSuccess(action: message.action, id: message.id)
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
                case .granted(let dialogShown):
                    self.sendPermissionResponse("granted", dialogShown: dialogShown, action: message.action, id: message.id)
                case .denied(let dialogShown):
                    self.sendPermissionResponse("denied", dialogShown: dialogShown, action: message.action, id: message.id)
                case .error(let errorMessage):
                    self.sendBridgeError(errorMessage, action: message.action, id: message.id)
                }
            }
        }
    }

    private func sendPermissionResponse(_ resultValue: String, dialogShown: Bool, action: String, id: UUID) {
        let response = BridgeMessage(
            type: .response,
            action: action,
            payload: .object(["result": .string(resultValue), "dialogShown": .bool(dialogShown)]),
            id: id
        )
        facade?.sendToJS(response)
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

// MARK: - WKNavigationType String Representation

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

// MARK: - Haptic Handler

extension TransparentView {

    private func handleHaptic(message: BridgeMessage) {
        hapticService.handle(message: message)
        sendBridgeSuccess(action: message.action, id: message.id)
    }
}

// MARK: - Open Settings Handler

extension TransparentView {

    private func handleOpenSettings(message: BridgeMessage) {
        guard let settingsType = SettingsRequestParser.parse(from: message) else {
            sendBridgeError("Invalid or unknown settings type", action: message.action, id: message.id)
            return
        }
        Logger.common(message: "[WebView] openSettings: type='\(settingsType.rawValue)'", level: .info, category: .webViewInAppMessages)

        switch settingsType {
        case .notifications:
            handleOpenNotificationSettings(message: message)
        case .application:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                sendBridgeError("Failed to create application settings URL", action: message.action, id: message.id)
                return
            }
            openViaUIApplication(url: url, message: message)
        }
    }

    private func handleOpenNotificationSettings(message: BridgeMessage) {
        PushPermissionHelper.openPushNotificationSettings { [weak self] _ in
            DispatchQueue.main.async {
                self?.sendBridgeSuccess(action: message.action, id: message.id)
            }
        }
    }
}

// MARK: - Motion Handlers

extension TransparentView {

    func handleSystemShake() {
        guard isMotionServiceInitialized else { return }
        motionService.handleSystemShake()
    }

    private func handleMotionStart(message: BridgeMessage) {
        guard let payload = extractMotionPayload(from: message) else {
            sendBridgeError("Invalid payload: missing 'gestures' array", action: message.action, id: message.id)
            return
        }

        guard case .array(let gestureArray) = payload["gestures"] else {
            sendBridgeError("Invalid payload: 'gestures' must be an array", action: message.action, id: message.id)
            return
        }

        var gestures = Set<MotionGesture>()
        for item in gestureArray {
            if case .string(let name) = item, let gesture = MotionGesture(rawValue: name) {
                gestures.insert(gesture)
            }
        }

        guard !gestures.isEmpty else {
            sendBridgeError("No valid gestures provided. Available: shake, flip", action: message.action, id: message.id)
            return
        }

        let result = motionService.startMonitoring(gestures: gestures)

        if result.allUnavailable {
            sendBridgeError(
                "No sensors available for requested gestures: \(result.unavailable.map(\.rawValue).joined(separator: ", "))",
                action: message.action,
                id: message.id
            )
        } else {
            var payload: [String: JSONValue] = ["success": .bool(true)]
            if !result.unavailable.isEmpty {
                payload["unavailable"] = .array(result.unavailable.map { .string($0.rawValue) })
            }
            let response = BridgeMessage(
                type: .response,
                action: message.action,
                payload: .object(payload),
                id: message.id
            )
            facade?.sendToJS(response)
        }
    }

    private func handleMotionStop(message: BridgeMessage) {
        motionService.stopMonitoring()
        sendBridgeSuccess(action: message.action, id: message.id)
    }

    private func sendMotionEvent(gesture: MotionGesture, data: [String: Any]) {
        var payload: [String: JSONValue] = ["gesture": .string(gesture.rawValue)]
        for (key, value) in data {
            if let jsonValue = JSONValue(any: value) {
                payload[key] = jsonValue
            }
        }

        let event = BridgeMessage(
            type: .request,
            action: BridgeMessage.Action.motionEvent.rawValue,
            payload: .object(payload)
        )
        facade?.sendToJS(event)
    }

    private func extractMotionPayload(from message: BridgeMessage) -> [String: JSONValue]? {
        if case .string(let str) = message.payload,
           let data = str.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            return dict
        }
        if case .object(let dict) = message.payload {
            return dict
        }
        return nil
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
