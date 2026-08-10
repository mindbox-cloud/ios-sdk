//
//  EmbeddedBlockContentProviderFactoryTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

/// У фабрики одно обещание: провайдер — свой на каждый блок, а резолвер и обработчик действий —
/// общие. На нём держится независимость блоков с одинаковым id, поэтому оно проверяется отдельно.
///
/// Счётчик живых блоков общий на процесс, поэтому у каждого теста свой id: иначе тесты, идущие
/// параллельно, считали бы блоки друг друга.
@Suite("Embedded block content provider factory", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockContentProviderFactoryTests {

    /// Два блока с одним id — законный случай, и каждый обязан получить собственный провайдер:
    /// общий сделал бы их состояние и страницу одной на двоих.
    @Test("Every call makes its own provider")
    func eachCallMakesItsOwnProvider() {
        let id = "factory-independent-blocks"
        let factory = makeFactory()

        let first = factory.makeProvider(id: id)
        let second = factory.makeProvider(id: id)

        #expect(first !== second)
        withExtendedLifetime((first, second)) {
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 2)
        }
    }

    @Test("The provider is made for the requested id")
    func providerIsMadeForTheRequestedId() {
        let id = "factory-carries-the-id"
        let other = "factory-some-other-id"
        let factory = makeFactory()

        let provider = factory.makeProvider(id: id)

        withExtendedLifetime(provider) {
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 1)
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: other) == 0)
        }
    }

    /// Резолвер общий именно для того, чтобы несколько блоков с одним id разрешались одной загрузкой
    /// данных. Проверяется, что фабрика действительно передаёт провайдеру тот резолвер, а не заводит
    /// ему свой.
    @Test("The provider asks the shared resolver for its own id")
    func providerAsksTheSharedResolver() {
        let resolver = EmbeddedBlockResolverMock(resolution: .empty)
        let factory = EmbeddedBlockContentProviderFactory(resolver: resolver,
                                                          actionHandler: EmbeddedBlockActionHandlerMock())

        let provider = factory.makeProvider(id: "factory-shared-resolver")
        withExtendedLifetime(provider) {
            provider.start()
        }

        #expect(resolver.resolvedIds == ["factory-shared-resolver"])
    }

    // MARK: - Helpers

    /// Резолвер отвечает «пусто»: страницу для такого блока не создают, поэтому тестам фабрики не
    /// нужен настоящий вебвью.
    private func makeFactory() -> EmbeddedBlockContentProviderFactory {
        EmbeddedBlockContentProviderFactory(resolver: EmbeddedBlockResolverMock(resolution: .empty),
                                            actionHandler: EmbeddedBlockActionHandlerMock())
    }
}
