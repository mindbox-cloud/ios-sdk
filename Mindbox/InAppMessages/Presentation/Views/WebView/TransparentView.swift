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
    private let actionRegistry: WebBridgeActionRegistry
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
         = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers())) {
        self.actionRegistry = actionRegistry
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

    func makeStartPayload() -> JSONValue {
        facade?.makeStartPayload() ?? .string("{}")
    }
}

// MARK: - WebBridgeLifecycleHosting

extension TransparentView: WebBridgeLifecycleHosting {

    func bridgeDidInit() {
        // First, before anything else can read it: the no-cache retry policy decides whether a
        // failed subresource is worth healing by asking whether the page ever booted, and a
        // late flag silently disables that.
        hasReceivedInit = true
        quizInitTimeoutWorkItem?.cancel()
        // The page has proven it can boot — drop the retained retry content (mirror of
        // Android's handleInitAction cleanup; the policy's one-shot state stays).
        facade?.releaseRetainedContent()
        actionRegistry.handler(ofType: HapticActionHandler.self)?.prepare()
        webViewAction?.onInit()
    }

    func bridgeDidRequestClose() {
        quizInitTimeoutWorkItem?.cancel()
        // Whatever holds the device is released before the window goes: a haptic pattern
        // playing into a closed show, or a sensor callback reaching a dead page, is the
        // shape crashes come in.
        actionRegistry.tearDown()
        webViewAction?.onClose()
    }

    func bridgeDidRequestHide() {
        webViewAction?.onHide()
    }

    func bridgeDidClick(rawPayload: String) {
        webViewAction?.onCompleted(data: rawPayload)
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

        if message.type == .request, message.parsedAction == .ready, !isRegisteredForBroadcasts {
            isRegisteredForBroadcasts = true
            webPageRegistry.register(self)
        }

        // Journaling only: the dispatcher already refused an unknown action to the page.
        guard actionRegistry.handle(message, host: self) else {
            Logger.common(
                message: "[WebView] Unknown action: \(action) with \(data)",
                category: .webViewInAppMessages
            )
            return
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
        let decision = WebViewNavigationPolicy.decision(for: navigationType, url: url)
        WebViewNavigationPolicy.log(decision, navigationType: navigationType, url: url, category: .webViewInAppMessages)

        switch decision {
        case .allow:
            decisionHandler(.allow)

        case .handInBack(let url):
            decisionHandler(.cancel)

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
}
