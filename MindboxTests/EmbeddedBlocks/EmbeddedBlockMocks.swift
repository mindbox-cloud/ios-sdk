//
//  EmbeddedBlockMocks.swift
//  MindboxTests
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
@testable import Mindbox

extension EmbeddedBlockWebContent {

    static let stub = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/block.html")!)

    static let other = EmbeddedBlockWebContent(url: URL(string: "https://mindbox.ru/another-block.html")!)
}

extension EmbeddedBlockPageAction {

    static let openUrlStub = EmbeddedBlockPageAction(type: "openUrl", payload: ["url": "https://mindbox.ru"])
}

/// Страница без WebKit: тесты сами решают, что и когда она скажет нативной стороне.
final class EmbeddedBlockPageMock: EmbeddedBlockPageHosting {

    let view = UIView()

    var onMessage: ((EmbeddedBlockPageMessage) -> Void)?

    var onLoadFailure: (() -> Void)?

    var onLoadFinish: (() -> Void)?

    var loadCount = 0
    var cancelCount = 0

    func load() {
        loadCount += 1
    }

    func cancel() {
        cancelCount += 1
    }

    func send(_ message: EmbeddedBlockPageMessage) {
        onMessage?(message)
    }

    func failLoad() {
        onLoadFailure?()
    }

    func finishLoad() {
        onLoadFinish?()
    }
}

final class EmbeddedBlockReadinessOverridesMock: EmbeddedBlockReadinessOverriding {

    var treatsLoadedPageAsReady: Bool

    init(treatsLoadedPageAsReady: Bool = false) {
        self.treatsLoadedPageAsReady = treatsLoadedPageAsReady
    }
}

/// Считает, сколько страниц было создано и с каким контентом: перезагрузка обязана создать новую.
final class EmbeddedBlockPageFactoryMock {

    private(set) var pages: [EmbeddedBlockPageMock] = []
    private(set) var contents: [EmbeddedBlockWebContent] = []

    var page: EmbeddedBlockPageMock? { pages.last }

    func make(_ content: EmbeddedBlockWebContent) -> EmbeddedBlockPageHosting {
        contents.append(content)
        let page = EmbeddedBlockPageMock()
        pages.append(page)
        return page
    }
}

final class EmbeddedBlockResolverMock: EmbeddedBlockResolving {

    var resolution: EmbeddedBlockResolution

    /// `true` — ответ не приходит, пока тест не позовёт `flush()`: так проверяется резолв,
    /// доехавший уже после остановки или перезагрузки блока.
    var isDeferred = false

    private(set) var resolvedIds: [String] = []
    private(set) var forceRefreshHistory: [Bool] = []

    var resolveCount: Int { resolvedIds.count }

    private var pending: [(EmbeddedBlockResolution) -> Void] = []

    init(resolution: EmbeddedBlockResolution = .content(.stub)) {
        self.resolution = resolution
    }

    func resolve(_ id: String, forceRefresh: Bool, completion: @escaping (EmbeddedBlockResolution) -> Void) {
        resolvedIds.append(id)
        forceRefreshHistory.append(forceRefresh)

        if isDeferred {
            pending.append(completion)
        } else {
            completion(resolution)
        }
    }

    func flush() {
        let completions = pending
        pending = []
        completions.forEach { $0(resolution) }
    }
}

final class EmbeddedBlockActionHandlerMock: EmbeddedBlockActionHandling {

    private(set) var handledActions: [EmbeddedBlockPageAction] = []

    func handle(_ action: EmbeddedBlockPageAction) {
        handledActions.append(action)
    }
}

/// Открыватель ссылок, который ничего не открывает: тесты смотрят, что до системы дошло, а что нет.
final class EmbeddedBlockURLOpenerMock: EmbeddedBlockURLOpening {

    /// Что отвечать на вопрос «система это откроет?». `canOpenURL` пропускает системные схемы, и
    /// тесты политики схем должны проверять именно политику, а не этот ответ.
    var canOpenAnything = true

    private(set) var openedURLs: [URL] = []

    func canOpen(_ url: URL) -> Bool {
        canOpenAnything
    }

    func open(_ url: URL) {
        openedURLs.append(url)
    }
}

/// Провайдер со всеми подменёнными зависимостями — общая заготовка для тестов провайдера и
/// контейнера. Контейнер тестируется через настоящий провайдер: единственный шов внутри блока —
/// страница, и подменять больше нечего.
final class EmbeddedBlockTestBed {

    let resolver: EmbeddedBlockResolverMock
    let actionHandler: EmbeddedBlockActionHandlerMock
    let readinessOverrides: EmbeddedBlockReadinessOverridesMock
    let pageFactory: EmbeddedBlockPageFactoryMock
    let provider: EmbeddedBlockWebViewProvider

    var page: EmbeddedBlockPageMock? { pageFactory.page }

    init(id: String = "block-id",
         resolution: EmbeddedBlockResolution = .content(.stub),
         treatsLoadedPageAsReady: Bool = false) {
        let resolver = EmbeddedBlockResolverMock(resolution: resolution)
        let actionHandler = EmbeddedBlockActionHandlerMock()
        let readinessOverrides = EmbeddedBlockReadinessOverridesMock(treatsLoadedPageAsReady: treatsLoadedPageAsReady)
        let pageFactory = EmbeddedBlockPageFactoryMock()

        self.resolver = resolver
        self.actionHandler = actionHandler
        self.readinessOverrides = readinessOverrides
        self.pageFactory = pageFactory
        self.provider = EmbeddedBlockWebViewProvider(id: id,
                                                     resolver: resolver,
                                                     actionHandler: actionHandler,
                                                     readinessOverrides: readinessOverrides,
                                                     makePage: { pageFactory.make($0) })
    }
}

final class EmbeddedBlockViewDelegateMock: MindboxEmbeddedBlockViewDelegate {

    enum Event: Equatable {
        case loaded
        case failed
    }

    private(set) var events: [Event] = []

    func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.loaded)
    }

    func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView) {
        events.append(.failed)
    }
}
