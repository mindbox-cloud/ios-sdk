//
//  WebViewController.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import UIKit
import MindboxLogger

protocol WebVCDelegate: AnyObject {
    func closeTapWebViewVC()
    func closeTimeoutWebViewVC()
    func closeLoadFailedWebViewVC(reason: String)
}

final class WebViewController: UIViewController, InappViewControllerProtocol {

    // MARK: InappViewControllerProtocol

    var layers = [UIView]()
    var elements = [UIView]()
    let elementFactories: [ContentElementType: ElementFactory] = [
        .closeButton: CloseButtonElementFactory()
    ]

    let layersFactories: [ContentBackgroundLayerType: LayerFactory] = [
        .image: ImageLayerFactory()
    ]

    // MARK: Private properties

    private let model: ModalFormVariant
    private let id: String
    private let imagesDict: [String: UIImage]
    private let operation: (name: String, body: String)?
    private let tags: [String: String]?

    private let onPresented: () -> Void
    private let onCloseInApp: () -> Void
    private let onError: (InAppPresentationError) -> Void
    private let onTapAction: InAppMessageTapAction
    private let windowProvider: () -> UIWindow?
    var isTimeoutClose = false
    private var hasReportedTerminalError = false
    private var hasOnPresentedBeenCalled = false

    private enum Constants {
        static let defaultAlphaBackgroundColor: CGFloat = 0.0
    }

    private var transparentWebView: TransparentView?

    // MARK: Init

    init(
        model: ModalFormVariant,
        id: String,
        imagesDict: [String: UIImage],
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onCloseInApp: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void,
        windowProvider: @escaping () -> UIWindow? = WebViewController.defaultWindowProvider,
        operation: (name: String, body: String)?,
        tags: [String: String]?
    ) {
        self.model = model
        self.id = id
        self.imagesDict = imagesDict
        self.operation = operation
        self.tags = tags
        self.onPresented = onPresented
        self.onCloseInApp = onCloseInApp
        self.onError = onError
        self.onTapAction = onTapAction
        self.windowProvider = windowProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Logger.common(message: "[WebView] Deinit WebViewVC", category: .webViewInAppMessages)
        transparentWebView?.cleanUp()
        // Stop the closed in-app's JS from running hidden on the parked warm instance.
        DI.injectOrFail(InAppWebViewPrewarmServiceProtocol.self).parkWarmWebView()
    }

    private func setupWebView() {
        guard let layer = model.content.background.layers.first else {
            reportErrorAndClose(
                .webviewPresentationFailed("[WebView] Missing background layer for in-app id \(id).")
            )
            return
        }

        switch layer {
        case .webview(let webviewLayer):
            let webView = TransparentView(frame: .zero, params: webviewLayer.params, userAgent: createUserAgent(), operation: operation, inAppId: id, tags: tags)
            view.addSubview(webView)

            setupConstraints(for: webView, in: view)

            webView.delegate = self
            webView.webViewAction = self
            webView.loadHTMLPage(
                baseUrl: webviewLayer.baseUrl,
                contentUrl: webviewLayer.contentUrl
            )

            self.transparentWebView = webView
        default:
            reportErrorAndClose(
                .webviewPresentationFailed("[WebView] Invalid background layer type for in-app id \(id).")
            )
            return
        }
    }

    private func setupConstraints(for view: UIView, in parentView: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: parentView.topAnchor),
            view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
    }

    // MARK: Life cycle

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(Constants.defaultAlphaBackgroundColor)
        let onTapDimmedViewGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(onTapDimmedView)
        )
        view.addGestureRecognizer(onTapDimmedViewGesture)
        view.isUserInteractionEnabled = true
        setupWebView()
        addLifecycleObservers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Every dismissal path (close action, dim-tap, timeout) goes through here while
        // the page is still alive — the last moment the learned-hosts capture can run.
        transparentWebView?.captureObservedResourceHosts()
        super.viewWillDisappear(animated)
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            transparentWebView?.handleSystemShake()
        }
        super.motionEnded(motion, with: event)
    }

    // MARK: Private methods

    @objc
    private func onTapDimmedView() {
        onClose()
    }
    
    private func addLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func removeLifecycleObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc
    private func appDidEnterBackground() {
        guard !hasOnPresentedBeenCalled, !hasReportedTerminalError else { return }
        transparentWebView?.cancelTimeoutTimer()
        Logger.common(message: "[WebView] App entered background, timeout timer cancelled for in-app id \(id)", category: .webViewInAppMessages)
    }

    @objc
    private func appWillEnterForeground() {
        guard !hasOnPresentedBeenCalled, !hasReportedTerminalError else { return }
        transparentWebView?.restartTimeoutTimer()
        Logger.common(message: "[WebView] App entering foreground, timeout timer restarted for in-app id \(id)", category: .webViewInAppMessages)
    }

    private func createUserAgent() -> String {
        SDKUserAgent.build()
    }
}

extension WebViewController: WebVCDelegate {
    func closeTapWebViewVC() {
        Logger.common(message: "[WebView] WebViewVC closeWebView", category: .webViewInAppMessages)
        onClose()
    }
    
    func closeTimeoutWebViewVC() {
        Logger.common(message: "[WebView] WebViewVC closeTimeoutOrErrorWebViewVC", category: .webViewInAppMessages)
        reportErrorAndClose(
            Self.timeoutError(
                readyCheckGaveUp: transparentWebView?.readyCheckDidGiveUp == true,
                inAppId: id,
                httpErrorDetail: transparentWebView?.noCacheRetryTelemetryDetail
            )
        )
    }

    /// The init timeout is the single closing authority, but monitoring must still tell
    /// "the page loaded and its JS bridge never appeared" (a content defect) apart from
    /// "the page never finished loading" (a load defect). `httpErrorDetail` adds the
    /// concrete cause when a script subresource answered with an HTTP error — with it a
    /// poisoned-cache death names the resource and status instead of a generic timeout.
    static func timeoutError(readyCheckGaveUp: Bool, inAppId: String, httpErrorDetail: String? = nil) -> InAppPresentationError {
        let suffix = httpErrorDetail.map { " \($0)" } ?? ""
        return readyCheckGaveUp
            ? .webviewPresentationFailed("[WebView] JS bridge missing after page load (init timeout) for in-app id \(inAppId).\(suffix)")
            : .webviewLoadFailed("[WebView] WebView initialization timeout for in-app id \(inAppId).\(suffix)")
    }

    func closeLoadFailedWebViewVC(reason: String) {
        Logger.common(message: "[WebView] WebViewVC closeLoadFailedWebViewVC. Reason: \(reason)", category: .webViewInAppMessages)
        reportErrorAndClose(
            .webviewLoadFailed(reason)
        )
    }
}

extension WebViewController: WebViewAction {

    func onInit() {
        Logger.common(message: "[WebView] TransparentWebView: received init action", category: .webViewInAppMessages)
        removeLifecycleObservers()
        DispatchQueue.main.async {
            if let window = self.windowProvider() {
                window.isUserInteractionEnabled = true
                UIView.animate(withDuration: 0.3) {
                    window.alpha = 1.0
                }
                window.makeKeyAndVisible()
                self.notifyPresentedIfNeeded()
                Logger.common(message: "[WebView] TransparentWebView: Window is now visible", category: .webViewInAppMessages)
            }
        }
    }

    func onCompleted(data: String) {
        Logger.common(message: "[WebView] WebViewVC completedWebView \(data)", category: .webViewInAppMessages)
        do {
            let jsonData = data.data(using: .utf8) ?? Data()
            let dto = try JSONDecoder().decode(ContentBackgroundLayerActionDTO.self, from: jsonData)
            let action = try LayerActionFilterService().filter(dto)

            guard let tapData = action.handleTap() else { return }
            onTapAction(tapData.url, tapData.payload)
        } catch {
            Logger.common(message: "[WebView] WebViewVC completedWebView. Error on decoding or filtering action. Error: \(error)", category: .webViewInAppMessages)
        }
    }

    func onClose() {
        Logger.common(message: "[WebView] WebViewVC closeWebView", category: .webViewInAppMessages)
        onCloseInApp()
    }

    func onHide() {
        DispatchQueue.main.async {
            if let window = self.windowProvider() {
                window.isUserInteractionEnabled = false
                window.alpha = 0.00
                Logger.common(message: "[WebView] TransparentWebView: Window is now non-interactive and transparent", category: .webViewInAppMessages)
            }
        }
    }
    
    func onLog(message: String) {
        Logger.common(message: "[JS] \(message)", category: .webViewInAppMessages)
    }
}

private extension WebViewController {
    static func defaultWindowProvider() -> UIWindow? {
        UIApplication.shared.windows.first(where: { $0.rootViewController is WebViewController })
    }

    func notifyPresentedIfNeeded() {
        guard !hasOnPresentedBeenCalled else {
            return
        }
        hasOnPresentedBeenCalled = true
        onPresented()
    }

    func reportErrorAndClose(_ error: InAppPresentationError) {
        guard !hasReportedTerminalError else {
            return
        }
        hasReportedTerminalError = true
        isTimeoutClose = true
        onError(error)
        onClose()
    }
}
