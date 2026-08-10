//
//  EmbeddedBlockWebViewPage.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import WebKit
import MindboxLogger

/// Страница встроенного блока в WKWebView.
///
/// Вебвью берётся из `InAppWebViewFactory` — того же места, где настраиваются вебвью инаппов:
/// блок получает тот же user agent и тот же `WKWebsiteDataStore`, а значит и общий HTTP-кеш.
final class EmbeddedBlockWebViewPage: NSObject, EmbeddedBlockPageHosting {

    /// Имя обработчика своё, пока блоки не переехали на общий мост инаппов.
    private enum Constants {
        static let handlerName = "mindboxEmbeddedBlock"
    }

    let webView: WKWebView

    var view: UIView { webView }

    var onMessage: ((EmbeddedBlockPageMessage) -> Void)?

    var onLoadFailure: (() -> Void)?

    var onLoadFinish: (() -> Void)?

    private let content: EmbeddedBlockWebContent

    init(content: EmbeddedBlockWebContent, webView: WKWebView = InAppWebViewFactory.make()) {
        self.content = content
        self.webView = webView
        super.init()

        setUpWebView()
        attachBridge()
    }

    deinit {
        detachBridge()
    }

    func load() {
        switch content.source {
        case .url(let url):
            webView.load(URLRequest(url: url))
        case .html(let html):
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func cancel() {
        webView.stopLoading()
    }

    private func setUpWebView() {
        webView.navigationDelegate = self

        // Фон прозрачный: сквозь зазоры в контенте должен просвечивать фон приложения, а не белый лист.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Высота контейнера равна высоте контента, вертикально скроллить нечего — иначе блок
        // пружинил бы под пальцем на каждом горизонтальном свайпе.
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    /// Мост живёт столько же, сколько страница: он ставится один раз и снимается только вместе с
    /// ней. Раньше его снимала `cancel()` — из-за этого вернуть страницу в окно можно было только
    /// перезагрузкой, иначе она оставалась глухой. От сообщений остановленной страницы защищает
    /// провайдер, а не отсутствие моста.
    private func attachBridge() {
        let controller = webView.configuration.userContentController
        // Идемпотентно: вебвью может прийти из переиспользования и нести обработчик с этим именем
        // от прошлого владельца.
        controller.removeScriptMessageHandler(forName: Constants.handlerName)
        // WKUserContentController держит обработчик сильно, поэтому в него идёт слабый прокси —
        // иначе страница и вебвью не освободятся никогда.
        controller.add(EmbeddedBlockWebViewMessageProxy(receiver: self), name: Constants.handlerName)
    }

    private func detachBridge() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.handlerName)
    }

    fileprivate func receive(body: Any) {
        guard let message = EmbeddedBlockPageMessage(body: body) else {
            Logger.common(message: "[EmbeddedBlock] Unknown page message: \(body)", category: .embeddedBlocks)
            return
        }

        onMessage?(message)
    }
}

/// Навигация судит только о своём: загрузка провалилась или документ доехал. Готовность блока из
/// этого не следует — о ней говорит сама страница своим `ready`, а загруженный документ слушает
/// одна лишь отладочная подмена готовности.
extension EmbeddedBlockWebViewPage: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportLoadFailure(error, phase: "navigation")
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        reportLoadFailure(error, phase: "provisional navigation")
    }
}

private extension EmbeddedBlockWebViewPage {

    /// Отменённая навигация — не провал загрузки, и выдавать её за провал нельзя: блок схлопнулся бы
    /// на ровном месте и остался бы дыркой нулевой высоты до конца жизни экрана. WebKit отдаёт
    /// `NSURLErrorCancelled` в двух совершенно обычных случаях: навигацию вытеснила следующая —
    /// клиентский редирект, страница загрузится сама, — и навигацию остановили мы, вызвав `cancel()`
    /// на уехавшем с экрана блоке. Второй случай к тому же приходит уже после того, как блок
    /// вернулся в окно, поэтому провайдер его своим `isStarted` не отфильтрует.
    func reportLoadFailure(_ error: Error, phase: String) {
        let error = error as NSError

        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else {
            Logger.common(message: "[EmbeddedBlock] Page \(phase) was cancelled, not a load failure",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Page \(phase) failed: \(error.localizedDescription)",
                      category: .embeddedBlocks)
        onLoadFailure?()
    }
}

/// Слабая прослойка между `WKUserContentController` и страницей.
private final class EmbeddedBlockWebViewMessageProxy: NSObject, WKScriptMessageHandler {

    private weak var receiver: EmbeddedBlockWebViewPage?

    init(receiver: EmbeddedBlockWebViewPage) {
        self.receiver = receiver
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        receiver?.receive(body: message.body)
    }
}
