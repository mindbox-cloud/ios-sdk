//
//  ModalViewController.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import UIKit
import MindboxLogger

protocol WebVCDelegate: AnyObject {
    func closeTapWebViewVC()
    func closeTimeoutWebViewVC()
}

extension WebViewController: WebVCDelegate {
    func closeTapWebViewVC() {
        Logger.common(message: "[WebView] WebViewVC closeWebView", category: .webViewInAppMessages)
        onClose()
    }
    
    func closeTimeoutWebViewVC() {
        isTimeoutClose = true
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        Logger.common(message: "[WebView] WebViewVC closeTimeoutOrErrorWebViewVC", category: .webViewInAppMessages)
        onClose()
    }
}

extension WebViewController: WebViewAction {

    func onInit() {
        Logger.common(message: "[WebView] TransparentWebView: received init action", category: .webViewInAppMessages)
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first(where: {
                $0.rootViewController is WebViewController
            }) {
                window.isUserInteractionEnabled = true
                UIView.animate(withDuration: 0.3) {
                    window.alpha = 1.0
                }
                window.makeKeyAndVisible()
                Logger.common(message: "[WebView] TransparentWebView: Window is now visible", category: .webViewInAppMessages)
            }
        }
    }

    func onCompleted(data: String) {
        Logger.common(message: "[WebView] WebViewVC completedWebView \(data)", category: .webViewInAppMessages)
        do {
            let jsonData = data.data(using: .utf8) ?? Data()
            let action = try JSONDecoder().decode(ContentBackgroundLayerActionDTO.self, from: jsonData)
            let service = LayerActionFilterService()
            let layer = try service.filter(action)
            onTapAction(layer)
        } catch {
            Logger.common(message: "[WebView] WebViewVC completedWebView. Error on decoding or filtering action. Error: \(error)", category: .webViewInAppMessages)
            onTapAction(nil)
        }
    }

    func onClose() {
        Logger.common(message: "[WebView] WebViewVC closeWebView", category: .webViewInAppMessages)
        onCloseInApp()
    }

    func onHide() {
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first(where: {
                $0.rootViewController is WebViewController
            }) {
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

    private let model: WebviewFormVariant
    private let id: String
    private let imagesDict: [String: UIImage]

    private let onPresented: () -> Void
    private let onCloseInApp: () -> Void
    private let onTapAction: (ContentBackgroundLayerAction?) -> Void
    var isTimeoutClose = false

    private var viewWillAppearWasCalled = false

    private enum Constants {
        static let defaultAlphaBackgroundColor: CGFloat = 0.0
    }

    private var transparentWebView: TransparentWebView?

    // MARK: Init

    init(
        model: WebviewFormVariant,
        id: String,
        imagesDict: [String: UIImage],
        onPresented: @escaping () -> Void,
        onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void,
        onCloseInApp: @escaping () -> Void
    ) {
        self.model = model
        self.id = id
        self.imagesDict = imagesDict
        self.onPresented = onPresented
        self.onCloseInApp = onCloseInApp
        self.onTapAction = onTapAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Logger.common(message: "[WebView] Deinit WebViewVC", category: .webViewInAppMessages)
        transparentWebView?.cleanUp()
    }

    private func setupWebView() {
        guard let layer = model.content.background.layers.first else {
            closeTapWebViewVC()
            return
        }

        switch layer {
        case .webview(let webviewLayer):
            let webView = TransparentWebView(frame: .zero, params: webviewLayer.params)
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
            closeTapWebViewVC()
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !viewWillAppearWasCalled else { return }
        viewWillAppearWasCalled = true
        onPresented()
    }

    // MARK: Private methods

    @objc
    private func onTapDimmedView() {
        onClose()
    }
}
