//
//  MindboxWebViewBlock.swift
//  Mindbox
//
//  Created by Uatkam Utekeshev on 20.07.2026.
//

import UIKit
import WebKit
import MindboxLogger

/// Prototype of an embedded WebView block that a host app can place anywhere in its UI.
/// The integrating app provides the URL to load; the block reports and survives
/// web-content-process terminations (auto-reloads and counts them) so we can measure
/// how often the system kills the WebView in real usage.
public class MindboxWebViewBlock: UIView {

    /// Called on the main thread every time the web content process is killed by the system.
    /// The argument is the total number of terminations observed by this instance.
    public var onWebContentProcessTerminated: ((Int) -> Void)?

    /// Called on the main thread when a navigation finishes or fails.
    public var onLoadFinished: ((Result<Void, Error>) -> Void)?

    /// Called on the main thread when the page reports its content height through
    /// the `mindboxBlockHeight` JS bridge. All layout math lives in the page's CSS/JS;
    /// the native side only consumes the resulting number.
    public var onContentHeightChanged: ((CGFloat) -> Void)?

    /// Last height reported by the page, in points. Kept across process kills so the
    /// block doesn't collapse while the page re-renders after a reload.
    public private(set) var contentHeight: CGFloat? {
        didSet { invalidateIntrinsicContentSize() }
    }

    public private(set) var processTerminationCount = 0

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight ?? UIView.noIntrinsicMetric)
    }

    private enum Content {
        case url(URL)
        case html(String, baseURL: URL?)

        var description: String {
            switch self {
            case .url(let url):
                return url.absoluteString
            case .html:
                return "inline HTML"
            }
        }
    }

    /// Cache policy applied to every URL load, including automatic reloads after a
    /// web-content-process kill. `.returnCacheDataElseLoad` lets the block restore
    /// from the HTTP cache without hitting the network.
    public var urlCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy

    /// Delay before the automatic reload after a web-content-process kill. Zero in
    /// production; QA tooling raises it to keep the dead (blank) state on screen
    /// long enough to see what a crash actually looks like.
    public var terminationReloadDelay: TimeInterval = 0

    private var content: Content?
    private var webView: WKWebView?

    public init(url: URL? = nil) {
        super.init(frame: .zero)
        setupWebView()
        if let url {
            load(url: url)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.heightMessageName)
        Logger.common(message: "[WebViewBlock] Deinit, terminations observed: \(processTerminationCount)", category: .webViewInAppMessages)
    }

    /// Loads (or replaces) the URL displayed by the block.
    public func load(url: URL) {
        content = .url(url)
        Logger.common(message: "[WebViewBlock] Loading \(url.absoluteString)", category: .webViewInAppMessages)
        webView?.load(URLRequest(url: url, cachePolicy: urlCachePolicy))
    }

    /// Loads (or replaces) inline HTML content. Survives process termination the same
    /// way a URL does — the block keeps the string and re-renders it on reload.
    public func load(html: String, baseURL: URL? = nil) {
        content = .html(html, baseURL: baseURL)
        Logger.common(message: "[WebViewBlock] Loading inline HTML (\(html.count) chars)", category: .webViewInAppMessages)
        webView?.loadHTMLString(html, baseURL: baseURL)
    }

    /// Reloads the current content from scratch.
    public func reload() {
        switch content {
        case .url(let url):
            load(url: url)
        case .html(let html, let baseURL):
            load(html: html, baseURL: baseURL)
        case nil:
            break
        }
    }

    static let heightMessageName = "mindboxBlockHeight"

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // Weak proxy: WKUserContentController retains its handlers, a direct `self`
        // would create a retain cycle through the web view.
        configuration.userContentController.add(WeakScriptMessageHandler(self), name: Self.heightMessageName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        self.webView = webView
    }
}

extension MindboxWebViewBlock: WKNavigationDelegate {

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        processTerminationCount += 1
        Logger.common(
            message: "[WebViewBlock] Web content process terminated (count: \(processTerminationCount)), reloading",
            category: .webViewInAppMessages
        )
        onWebContentProcessTerminated?(processTerminationCount)
        if terminationReloadDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + terminationReloadDelay) { [weak self] in
                self?.reload()
            }
        } else {
            reload()
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.common(message: "[WebViewBlock] Did finish navigation for \(content?.description ?? "nil")", category: .webViewInAppMessages)
        onLoadFinished?(.success(()))
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.common(message: "[WebViewBlock] Navigation failed: \(error.localizedDescription)", category: .webViewInAppMessages)
        onLoadFinished?(.failure(error))
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.common(message: "[WebViewBlock] Provisional navigation failed: \(error.localizedDescription)", category: .webViewInAppMessages)
        onLoadFinished?(.failure(error))
    }
}

extension MindboxWebViewBlock: WKScriptMessageHandler {

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.heightMessageName, let height = message.body as? Double, height > 0 else { return }
        let newHeight = CGFloat(height)
        guard newHeight != contentHeight else { return }
        Logger.common(message: "[WebViewBlock] Page reported content height: \(newHeight)", category: .webViewInAppMessages)
        contentHeight = newHeight
        onContentHeightChanged?(newHeight)
    }
}

/// WKUserContentController holds its message handlers strongly; this proxy keeps
/// the block from being retained by its own web view configuration.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
