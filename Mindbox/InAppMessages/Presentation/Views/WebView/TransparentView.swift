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
    private(set) var readyCheckFailure: String?
    private var hasReceivedInit = false
    private var initWaitStartedAt: TimeInterval?
    private var hasEndedBridgeSession = false
    private var hasCapturedObservedHosts = false
    private let noCacheRetryPolicy: WebViewNoCacheRetryPolicy
    lazy var webPageRegistry = MindboxWebPageRegistry.shared
    private var isRegisteredForBroadcasts = false

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
        if initWaitStartedAt == nil { initWaitStartedAt = CACurrentMediaTime() }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Constants.WebView.timeoutSeconds), execute: workItem)
    }

    private func takeInitWait() -> String? {
        guard let startedAt = initWaitStartedAt else { return nil }
        initWaitStartedAt = nil
        return String(format: "%.2fs", CACurrentMediaTime() - startedAt)
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
        if !hasReceivedInit, let waited = takeInitWait() {
            Logger.common(message: "[WebView] In-app \(inAppId): init received after \(waited)", category: .webViewInAppMessages)
        }
        hasReceivedInit = true
        quizInitTimeoutWorkItem?.cancel()
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
        lastReadyCheckedUrl = nil
        readyCheckFailure = nil
        readyChecker?.cancel()
        readyChecker = nil
    }

    func webBridge(_ bridge: MindboxWebBridge, didFinishNavigation url: URL?) {
        let urlString = url?.absoluteString ?? "unknown"
        Logger.common(message: "[WebView] WKNavigationDelegate: finished loading \(urlString)", category: .webViewInAppMessages)
        guard !hasEndedBridgeSession else { return }

        guard lastReadyCheckedUrl != urlString else { return }
        lastReadyCheckedUrl = urlString

        readyChecker?.cancel()
        let checker = WebViewReadyChecker(evaluate: { [weak self] script, completion in
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
