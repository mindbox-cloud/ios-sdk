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

    var facade: InappWebViewFacadeProtocol?
    private var quizInitTimeoutWorkItem: DispatchWorkItem?
    private var params: [String: JSONValue]?
    private var operation: (name: String, body: String)?
    private let userAgent: String
    private let inAppId: String
    let tags: [String: String]?

    /// Handlers for the actions that no longer live in the switch below. Built per show, not
    /// shared: handlers moving in here own state that belongs to one page.
    private let actionRegistry = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers())
    private var lastReadyCheckedUrl: String?
    private var readyChecker: WebViewReadyChecker?
    /// True when the page finished loading but the JS bridge never appeared within the
    /// ready-check budget — lets the init timeout report the accurate failure category.
    private(set) var readyCheckDidGiveUp = false
    /// True once the page has sent `init`. After that the init timeout is cancelled, so a
    /// later ready-check give-up (a post-load navigation dropped the bridge) has no other
    /// closing authority — it must close the show itself.
    private var hasReceivedInit = false
    private var hasCapturedObservedHosts = false
    private let noCacheRetryPolicy = WebViewNoCacheRetryPolicy {
        InAppWebViewDataStore.isCacheFeatureEnabled
    }
    lazy var featureToggleManager: FeatureToggleManager = DI.injectOrFail(FeatureToggleManager.self)
    lazy var databaseRepository: DatabaseRepositoryProtocol = DI.injectOrFail(DatabaseRepositoryProtocol.self)
    lazy var eventRepository: EventRepository = DI.injectOrFail(EventRepository.self)

    init(frame: CGRect, params: [String: JSONValue], userAgent: String, operation: (name: String, body: String)?, inAppId: String, tags: [String: String]?) {
        self.params = params
        self.operation = operation
        self.userAgent = userAgent
        self.inAppId = inAppId
        self.tags = tags
        super.init(frame: frame)
        commonInit()
    }

    override init(frame: CGRect) {
        self.params = nil
        self.operation = nil
        self.userAgent = ""
        self.inAppId = ""
        self.tags = nil
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.params = nil
        self.operation = nil
        self.userAgent = ""
        self.inAppId = ""
        self.tags = nil
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        readyChecker?.cancel()
        actionRegistry.tearDown()
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

    /// Persists the hosts this show's resources actually came from so the next launch's
    /// prewarm can preconnect to them. Called from `viewWillDisappear`, which every
    /// dismissal path (close action, dim-tap, timeout) goes through while the page is still
    /// alive; the once-flag is a cheap guard against a repeated disappear.
    func captureObservedResourceHosts() {
        guard !hasCapturedObservedHosts else { return }
        hasCapturedObservedHosts = true
        facade?.evaluateJavaScript(InAppWebViewPrewarmPlanner.observedHostsScript) { result in
            guard case .success(let value) = result, let hosts = value as? [String] else { return }
            DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self).rememberObservedHosts(hosts)
        }
    }

    func cancelTimeoutTimer() {
        quizInitTimeoutWorkItem?.cancel()
        quizInitTimeoutWorkItem = nil
    }

    func restartTimeoutTimer() {
        setupTimeoutTimer()
    }

    var noCacheRetryTelemetryDetail: String? {
        noCacheRetryPolicy.lastHTTPErrorDetail.map { detail in
            "Last script HTTP error: \(detail); no-cache retry attempted: \(noCacheRetryPolicy.hasRetried)."
        }
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

// MARK: - WebBridgeHost

extension TransparentView: WebBridgeHost {

    var contentId: String { inAppId }

    var logCategory: LogCategory { .webViewInAppMessages }

    var presentingViewController: UIViewController? { delegate as? UIViewController }

    /// A modal in-app exists only while it is on screen — unlike an embedded block, it has no
    /// off-screen life in which its page could keep talking.
    var isUserPresent: Bool { true }

    func send(_ message: BridgeMessage) {
        facade?.sendToJS(message)
    }
}

extension TransparentView: WebBridgeMessageDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
        let action = message.action
        let data = message.payloadString

        Logger.common(
            message: "[WebView] Bridge: received \(action) \(data)",
            category: .webViewInAppMessages
        )

        // Whatever the registry owns is fully handled there and never reaches the switch below.
        // The rest still lives here and moves out a group at a time.
        if actionRegistry.handle(message, host: self) {
            return
        }

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
            // Whatever holds the device is released before the window goes: a haptic pattern
            // playing into a closed show, or a sensor callback reaching a dead page, is the
            // shape crashes come in.
            actionRegistry.tearDown()
            webViewAction?.onClose()
        case .`init`:
            hasReceivedInit = true
            quizInitTimeoutWorkItem?.cancel()
            // The page has proven it can boot — drop the retained retry content (mirror of
            // Android's handleInitAction cleanup; the policy's one-shot state stays).
            facade?.releaseRetainedContent()
            actionRegistry.handler(ofType: HapticActionHandler.self)?.prepare()
            webViewAction?.onInit()
        case .click:
            webViewAction?.onCompleted(data: data)
        case .hide:
            webViewAction?.onHide()
        case .ready:
            facade?.sendReadyEvent(id: message.id)

        // Handled by the action registry above. Listed only to keep this switch exhaustive
        // while the remaining actions move out; unreachable.
        case .log, .localStateGet, .localStateSet, .localStateInit,
             .openLink, .settingsOpen, .permissionRequest,
             .haptic, .motionStart, .motionStop:
            break

        // Operations
        case .asyncOperation:
            handleAsyncOperation(message: message)
        case .syncOperation:
            handleSyncOperation(message: message)

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
        readyCheckDidGiveUp = false
        readyChecker?.cancel()
        readyChecker = nil
    }

    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        let urlString = url?.absoluteString ?? "unknown"
        Logger.common(message: "[WebView] WKNavigationDelegate: Upload completed \(urlString)", category: .webViewInAppMessages)

        // Avoid duplicate checks on multiple didFinish calls for the same URL.
        guard lastReadyCheckedUrl != urlString else { return }
        lastReadyCheckedUrl = urlString

        readyChecker?.cancel()
        let checker = WebViewReadyChecker(evaluate: { [weak self] script, completion in
            // Teardown: abandon the poll silently, exactly like cancel().
            guard let facade = self?.facade else { return }
            facade.evaluateJavaScript(script, completion: completion)
        })
        readyChecker = checker
        checker.run(onReady: {
            Logger.common(
                message: "[WebView] JS ready check for URL \(urlString): true",
                category: .webViewInAppMessages
            )
        }, onGiveUp: { [weak self] lastFailure in
            guard let self else { return }
            self.readyCheckDidGiveUp = true
            Logger.common(
                message: "[WebView] JS ready check gave up for URL \(urlString): \(lastFailure)",
                category: .webViewInAppMessages
            )
            // Before `init` the 7s timeout owns closing: its budget can expire while a slow
            // page is still booting the bridge, and the window is invisible until `init`
            // anyway; the flag above lets that timeout report the real category. After
            // `init` the timeout is already cancelled, so a give-up here (a post-load
            // navigation dropped the bridge) is the only signal left — close now, else the
            // in-app stays up with a dead bridge. The give-up flag makes this report
            // webview_presentation_failed, matching the pre-refactor behavior.
            if self.hasReceivedInit {
                self.delegate?.closeTimeoutWebViewVC()
            }
        })
    }
    
    func webBridge(_ bridge: MindboxWebBridge, didReceiveHTTPError url: String?) {
        let isRecoverable = InAppWebViewHTTPError.isRecoverable(url: url)
        Logger.common(
            message: "[WebView] Subresource error: \(InAppWebViewHTTPError.loadFailureDescription) for \(url ?? "nil")",
            level: isRecoverable ? .default : .debug,
            category: .webViewInAppMessages
        )
        guard noCacheRetryPolicy.onHTTPError(url: url, hasReceivedInit: hasReceivedInit) else { return }
        retryContentPageBypassingCache(failedURL: url)
    }

    private func retryContentPageBypassingCache(failedURL: String?) {
        Logger.common(
            message: "[WebView] Retrying In-App content load with cache bypassed (\(noCacheRetryPolicy.lastHTTPErrorDetail ?? "unknown"))",
            level: .info,
            category: .webViewInAppMessages
        )
        readyChecker?.cancel()
        readyChecker = nil
        restartTimeoutTimer()
        facade?.retryContentLoadBypassingCache(failedURL: failedURL) { [weak self] didRemoveAnything in
            self?.noCacheRetryPolicy.notePurgeOutcome(didRemoveAnything: didRemoveAnything)
            if !didRemoveAnything {
                Logger.common(
                    message: "[WebView] Cache purge found no entry for the failed script (write-behind race?) — one more retry may follow",
                    level: .debug,
                    category: .webViewInAppMessages
                )
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

    private func extractOperationParams(from message: BridgeMessage) -> (name: String, body: JSONValue)? {
        guard case .string(let str) = message.payload,
              let data = str.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data),
              case .string(let operation) = dict["operation"],
              !operation.isEmpty,
              let body = dict["body"] else {
            return nil
        }

        return (operation, body)
    }

    private func mergedOperationBodyString(_ body: JSONValue) -> String? {
        let gatedTags = featureToggleManager.gatedTags(tags)
        let mergedBody = JSONValue.mergingInAppTags(gatedTags, into: body)

        guard let bodyData = try? JSONEncoder().encode(mergedBody) else {
            return nil
        }
        return String(data: bodyData, encoding: .utf8)
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
        guard let params = extractOperationParams(from: message),
              let bodyString = mergedOperationBodyString(params.body) else {
            sendBridgeError("Invalid payload: could not parse operation/body or encode the operation body", action: message.action, id: message.id)
            return
        }

        let customEvent = CustomEvent(name: params.name, payload: bodyString)
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: customEvent).body)

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
        guard let params = extractOperationParams(from: message),
              let bodyString = mergedOperationBodyString(params.body) else {
            sendBridgeError("Invalid payload: could not parse operation/body or encode the operation body", action: message.action, id: message.id)
            return
        }

        let customEvent = CustomEvent(name: params.name, payload: bodyString)
        let event = Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)

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
                payload: .string(error.createDataJSON()),
                id: id
            )
        }
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

// MARK: - System shake

extension TransparentView {

    /// A shake is detected by the system and arrives at the view controller, so it is handed
    /// down to whoever is monitoring motion for this show.
    func handleSystemShake() {
        actionRegistry.handler(ofType: MotionActionHandler.self)?.handleSystemShake()
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
}
