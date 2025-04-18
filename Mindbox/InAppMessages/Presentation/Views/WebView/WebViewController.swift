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
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        Logger.common(message: "[WebView] WebViewVC closeTimeoutOrErrorWebViewVC", category: .webViewInAppMessages)
        onClose()
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
    private let onClose: () -> Void
    private let onTapAction: (ContentBackgroundLayerAction?) -> Void

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
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.id = id
        self.imagesDict = imagesDict
        self.onPresented = onPresented
        self.onClose = onClose
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
        let webView = TransparentWebView()
        view.addSubview(webView)

        setupConstraints(for: webView, in: view)
        
        guard let layer = model.content.background.layers.first else {
            closeTapWebViewVC()
            return
        }

        switch layer {
        case .webview(let webviewLayer):
            webView.delegate = self
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

// MARK: - GestureHandler

extension WebViewController: GestureHandler {
    @objc
    func imageTapped(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? InAppImageOnlyView else {
            return
        }

        let action = imageView.action
        onTapAction(action)
    }

    @objc
    func onCloseButton(_ gesture: UILongPressGestureRecognizer) {
        guard let crossView = gesture.view else {
            return
        }

        let location = gesture.location(in: crossView)
        let isInsideCrossView = crossView.bounds.contains(location)
        if gesture.state == .ended && isInsideCrossView {
            onClose()
        }
    }
}
