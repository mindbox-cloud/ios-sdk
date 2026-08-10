//
//  EmbeddedBlockWebViewPageTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import WebKit
@testable import Mindbox

/// Страница судит только о своём: загрузка не состоялась или документ доехал. Здесь проверяется
/// именно это разделение — и главное, что отменённая навигация в провалы не попадает.
@Suite("Embedded block web view page", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWebViewPageTests {

    /// Навигацию отменяют в двух совершенно обычных случаях: её вытеснил клиентский редирект и её
    /// остановил наш собственный `cancel()` на уехавшем с экрана блоке. Ни то, ни другое не значит,
    /// что блок сломан, — а провал сворачивает его насовсем.
    @Test("A cancelled provisional navigation is not a load failure")
    func cancelledProvisionalNavigationIsNotAFailure() {
        let bed = PageBed()

        bed.failProvisionalNavigation(with: bed.cancellationError)

        #expect(bed.failures == 0)
    }

    @Test("A cancelled navigation is not a load failure either")
    func cancelledNavigationIsNotAFailure() {
        let bed = PageBed()

        bed.failNavigation(with: bed.cancellationError)

        #expect(bed.failures == 0)
    }

    /// А настоящая ошибка сети — это ровно то, о чём страница обязана сказать.
    @Test("A real provisional navigation error is a load failure")
    func realProvisionalErrorIsAFailure() {
        let bed = PageBed()

        bed.failProvisionalNavigation(with: bed.error(code: NSURLErrorNotConnectedToInternet))

        #expect(bed.failures == 1)
    }

    @Test("A real navigation error is a load failure")
    func realNavigationErrorIsAFailure() {
        let bed = PageBed()

        bed.failNavigation(with: bed.error(code: NSURLErrorTimedOut))

        #expect(bed.failures == 1)
    }

    /// Отмена одной навигации не должна глушить страницу: следующая настоящая ошибка приходит как
    /// обычно.
    @Test("A cancellation does not swallow the failure that comes after it")
    func cancellationDoesNotSwallowLaterFailures() {
        let bed = PageBed()

        bed.failProvisionalNavigation(with: bed.cancellationError)
        bed.failProvisionalNavigation(with: bed.error(code: NSURLErrorCannotFindHost))

        #expect(bed.failures == 1)
    }

    @Test("A finished document is reported as a finish, not as a failure")
    func finishedDocumentIsReportedAsFinish() {
        let bed = PageBed()

        bed.finishNavigation()

        #expect(bed.finishes == 1)
        #expect(bed.failures == 0)
    }
}

/// Настоящая страница с настоящим вебвью, но без сети: тесты сами зовут методы навигационного
/// делегата — именно их разбор здесь и проверяется.
@MainActor
private final class PageBed {

    let page: EmbeddedBlockWebViewPage

    private(set) var failures = 0
    private(set) var finishes = 0

    var cancellationError: Error { error(code: NSURLErrorCancelled) }

    /// Через протокол, а не напрямую: у страницы есть и свойство `webView`, и методы делегата с тем
    /// же именем, и вызывать их стоит там, где имя однозначно.
    private var navigation: WKNavigationDelegate { page }

    init() {
        page = EmbeddedBlockWebViewPage(content: .stub, webView: WKWebView())
        page.onLoadFailure = { [weak self] in
            self?.failures += 1
        }
        page.onLoadFinish = { [weak self] in
            self?.finishes += 1
        }
    }

    func error(code: Int) -> Error {
        NSError(domain: NSURLErrorDomain, code: code)
    }

    func failProvisionalNavigation(with error: Error) {
        navigation.webView?(page.webView, didFailProvisionalNavigation: nil, withError: error)
    }

    func failNavigation(with error: Error) {
        navigation.webView?(page.webView, didFail: nil, withError: error)
    }

    func finishNavigation() {
        navigation.webView?(page.webView, didFinish: nil)
    }
}
