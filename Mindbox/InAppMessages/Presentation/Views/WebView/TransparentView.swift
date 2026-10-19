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

    private let actionRegistry: WebBridgeActionRegistry
    private let inappRequests: InappRequestServing
    private var lastReadyCheckedUrl: String?
    private var readyChecker: WebViewReadyChecker?
    /// Why the ready check gave up (native bridge vs. page handlers), `nil` while it hasn't —
    /// lets the init timeout report the accurate failure category and say which half is missing.
    private(set) var readyCheckFailure: String?
    /// True once the page has sent `init`. After that the init timeout is cancelled, so a
    /// later ready-check give-up (a post-load navigation dropped the bridge) has no other
    /// closing authority — it must close the show itself.
    private var hasReceivedInit = false
    /// When the current wait for `init` started; nil once `init` came or the wait timed out.
    private var initWaitStartedAt: TimeInterval?
    private var hasEndedBridgeSession = false
    private var hasCapturedObservedHosts = false
    private let noCacheRetryPolicy: WebViewNoCacheRetryPolicy
    lazy var webPageRegistry = MindboxWebPageRegistry.shared
    /// A page joins the broadcast set on its first `ready`: registering earlier would aim
    /// `localState.changed` at a document that has no bridge yet.
    private var isRegisteredForBroadcasts = false

    /// - Parameter actionRegistry: The handlers this show runs with. Injectable so a test can
    ///   drive the real dispatch path with doubles behind it.
    init(frame: CGRect,
         params: [String: JSONValue],
         userAgent: String,
         operation: (name: String, body: String)?,
         inAppId: String,
         tags: [String: String]?,
         actionRegistry: WebBridgeActionRegistry
         = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers()),
         inappRequests: InappRequestServing = InappRequestService(),
         noCacheRetryPolicy: WebViewNoCacheRetryPolicy = WebViewNoCacheRetryPolicy()) {
        self.actionRegistry = actionRegistry
        self.inappRequests = inappRequests
        self.noCacheRetryPolicy = noCacheRetryPolicy
        self.params = params
        self.operation = operation
        self.userAgent = userAgent
        self.inAppId = inAppId
        self.tags = tags
        super.init(frame: frame)
        commonInit()
    }

    override init(frame: CGRect) {
        self.actionRegistry = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers())
        self.inappRequests = InappRequestService()
        self.noCacheRetryPolicy = WebViewNoCacheRetryPolicy()
        self.params = nil
        self.operation = nil
        self.userAgent = ""
        self.inAppId = ""
        self.tags = nil
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.actionRegistry = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers())
        self.inappRequests = InappRequestService()
        self.noCacheRetryPolicy = WebViewNoCacheRetryPolicy()
        self.params = nil
        self.operation = nil
        self.userAgent = ""
        self.inAppId = ""
        self.tags = nil
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        endBridgeSession()
        Logger.common(message: "[WebView] Deinit TransparentView", category: .webViewInAppMessages)
    }

    private func commonInit() {
        actionRegistry.handler(ofType: MotionActionHandler.self)?.onShakeListeningChanged = { [weak self] isListening in
            self?.webViewAction?.onShakeListeningChanged(isListening)
        }
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
        (facade as? MindboxWebViewFacade)?.setTextInputDelegate(self)
    }

    func loadHTMLPage(baseUrl: String, contentUrl: String) {
        setupTimeoutTimer()

        facade?.loadHTML(baseUrl: baseUrl, contentUrl: contentUrl) { [weak self] in
            self?.delegate?.closeLoadFailedWebViewVC(reason: "Failed to fetch page HTML")
        }
    }

    func cleanUp() {
        facade?.cleanWebView()
    }

    func endBridgeSession() {
        guard !hasEndedBridgeSession else { return }
        hasEndedBridgeSession = true
        cancelTimeoutTimer()
        readyChecker?.cancel()
        readyChecker = nil
        actionRegistry.tearDown()
    }

    func endShow() {
        if !hasReceivedInit, let waited = takeInitWait() {
            Logger.common(message: "[WebView] In-app \(inAppId): closed before init after \(waited)", category: .webViewInAppMessages)
        }
        endBridgeSession()
        captureObservedResourceHosts()
        facade?.endShow()
    }

    /// Persists the hosts this show's resources actually came from so the next launch's
    /// prewarm can preconnect to them.
    private func captureObservedResourceHosts() {
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
            self?.initWaitStartedAt = nil
            self?.delegate?.closeTimeoutWebViewVC()
        }
        quizInitTimeoutWorkItem = workItem
        if initWaitStartedAt == nil { initWaitStartedAt = ProcessInfo.processInfo.systemUptime }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Constants.WebView.timeoutSeconds), execute: workItem)
    }

    /// How long the page has been waited for, as "2.37s", or nil when no wait is running; ends the wait.
    private func takeInitWait() -> String? {
        guard let startedAt = initWaitStartedAt else { return nil }
        initWaitStartedAt = nil
        return String(format: "%.2fs", ProcessInfo.processInfo.systemUptime - startedAt)
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
        guard !hasEndedBridgeSession else {
            Logger.common(message: "[WebView] Bridge: ignoring \(message.type.rawValue) \(message.action) to the page, the show has closed",
                          category: .webViewInAppMessages)
            return
        }
        facade?.sendToJS(message)
    }

    func makeStartPayload(_ completion: @escaping (JSONValue) -> Void) {
        guard let facade else {
            completion(.string("{}"))
            return
        }
        facade.makeStartPayload(completion)
    }
}

// MARK: - WebBridgeLifecycleHosting

extension TransparentView: WebBridgeLifecycleHosting {

    func bridgeDidInit() {
        // First, before anything else can read it: the no-cache retry policy decides whether a
        // failed subresource is worth healing by asking whether the page ever booted, and a
        // late flag silently disables that.
        if !hasReceivedInit, let waited = takeInitWait() {
            Logger.common(message: "[WebView] In-app \(inAppId): init received after \(waited)", category: .webViewInAppMessages)
        }
        hasReceivedInit = true
        quizInitTimeoutWorkItem?.cancel()
        // The page has proven it can boot — drop the retained retry content (mirror of
        // Android's handleInitAction cleanup; the policy's one-shot state stays).
        facade?.releaseRetainedContent()
        actionRegistry.handler(ofType: HapticActionHandler.self)?.prepare()
        webViewAction?.onInit()
    }

    func bridgeDidRequestClose() {
        endBridgeSession()
        webViewAction?.onClose()
    }

    func bridgeDidRequestHide() {
        webViewAction?.onHide()
    }

    func bridgeDidClick(rawPayload: String) {
        webViewAction?.onCompleted(data: rawPayload)
    }
}

// MARK: - WebBridgeInappRequestHosting

extension TransparentView: WebBridgeInappRequestHosting {

    func bridgeDidAskShowableInapps(_ ids: [String], completion: @escaping ([String]) -> Void) {
        inappRequests.showableInappIds(among: ids, askedBy: inAppId, completion: completion)
    }

    func bridgeDidRequestShowInApp(id: String,
                                   params: [String: JSONValue],
                                   completion: @escaping (Result<Void, BridgeErrorCode>) -> Void) {
        inappRequests.showInapp(id: id, params: params, proceedIf: { [weak self] in
            self?.hasEndedBridgeSession == false
        }, completion: completion)
    }
}

extension TransparentView: WebBridgeMessageDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didReceiveBridgeMessage message: BridgeMessage) {
        let action = message.action

        guard !hasEndedBridgeSession else {
            Logger.common(message: "[WebView] Bridge: ignoring \(message.type.rawValue) \(action), the show has closed",
                          category: .webViewInAppMessages)
            return
        }

        let data = message.payloadString

        Logger.common(
            message: "[WebView] Bridge: received \(action) \(data)",
            category: .webViewInAppMessages
        )

        if message.type == .request, message.parsedAction == .ready, !isRegisteredForBroadcasts {
            isRegisteredForBroadcasts = true
            webPageRegistry.register(self)
        }

        if message.type == .error {
            bridgeDidRequestClose()
            return
        }

        actionRegistry.handle(message, host: self)
    }
}

// MARK: - WKNavigationDelegate

extension TransparentView: WebBridgeNavigationDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didStartProvisionalNavigation url: URL?) {
        Logger.common(message: "[WebView] WKNavigationDelegate: start loading URL \(url?.absoluteString ?? "unknown")", category: .webViewInAppMessages)
        // Reset per-navigation checks (e.g. redirects / re-loads).
        lastReadyCheckedUrl = nil
        readyCheckFailure = nil
        readyChecker?.cancel()
        readyChecker = nil
    }

    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        let urlString = url?.absoluteString ?? "unknown"
        Logger.common(message: "[WebView] WKNavigationDelegate: finished loading \(urlString)", category: .webViewInAppMessages)
        guard !hasEndedBridgeSession else { return }

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
            self.readyCheckFailure = lastFailure
            Logger.common(
                message: "[WebView] JS ready check gave up for URL \(urlString): \(lastFailure)",
                category: .webViewInAppMessages
            )
            // Before `init` the 7s timeout owns closing: its budget can expire while a slow
            // page is still booting the bridge, and the window is invisible until `init`
            // anyway; the flag above lets that timeout report the real category. After
            // `init` the timeout is already cancelled, so a give-up here (a post-load
            // navigation dropped the bridge) is the only signal left — close now, else the
            // in-app stays up with a dead bridge, reported as webview_presentation_failed.
            if self.hasReceivedInit {
                self.delegate?.closeBridgeLostWebViewVC()
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
        guard !hasEndedBridgeSession else { return }
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
            reason: "Page failed to load: \((error as NSError).code) \(error.localizedDescription)"
        )
    }
    
    func webBridge(_ bridge: MindboxWebBridge, decidePolicyFor url: URL?, navigationType: WKNavigationType, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let decision = WebViewNavigationPolicy.decision(for: navigationType, url: url)

        switch decision {
        case .allow:
            WebViewNavigationPolicy.log(decision, navigationType: navigationType, url: url, category: .webViewInAppMessages)
            decisionHandler(.allow)

        case .handInBack(let url):
            decisionHandler(.cancel)

            guard !hasEndedBridgeSession else {
                Logger.common(message: "[WebView] Bridge: ignoring intercepted navigation (\(navigationType.debugLabel)) to \(url?.absoluteString ?? "unknown"), the show has closed",
                              category: .webViewInAppMessages)
                return
            }
            WebViewNavigationPolicy.log(decision, navigationType: navigationType, url: url, category: .webViewInAppMessages)

            guard let url = url else { return }

            let event = BridgeMessage(
                type: .request,
                action: BridgeMessage.Action.navigationIntercepted,
                payload: .object(["url": .string(url.absoluteString)])
            )
            facade?.sendToJS(event)
        }
    }
}

// MARK: - MindboxWebPage

extension TransparentView: MindboxWebPage {

    func push(_ action: BridgeMessage.Action, payload: JSONValue) {
        guard !hasEndedBridgeSession else {
            Logger.common(message: "[WebView] Bridge: ignoring push \(action.rawValue), the show has closed",
                          category: .webViewInAppMessages)
            return
        }
        facade?.sendToJS(BridgeMessage(type: .request, action: action, payload: payload))
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
    /// The page started or stopped listening for a shake.
    func onShakeListeningChanged(_ isListening: Bool)
    /// The page started or stopped editing text.
    func onTextEditingChanged(_ isEditing: Bool)
}

extension TransparentView: WebBridgeTextInputDelegate {
    func webBridge(_ bridge: MindboxWebBridge, didChangeTextEditing isEditing: Bool) {
        webViewAction?.onTextEditingChanged(isEditing)
    }
}
