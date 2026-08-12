//
//  EmbeddedBlockCoordinatorTests.swift
//  MindboxTests
//
//  Created by vailence on 12.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import SwiftUI
@testable import Mindbox

/// Координатор пишет доложенную контейнером презентацию не сразу, а отложенно — на следующем витке
/// главной очереди. `dismantleUIView` глушит колбэки контейнера, но уже поставленную запись из
/// очереди не достать — её отменяет `detach()`: подписка перепроверяется в момент исполнения.
///
/// Сьют не помечен `@available(iOS 13.0, *)` — макросы `@Suite`/`@Test` не применяются к таким
/// объявлениям. Таргет тестов собирается под iOS 12, поэтому доступность SwiftUI-типов каждый тест
/// открывает себе сам через `guard #available`.
@Suite("Embedded block coordinator", .tags(.embeddedBlocks))
struct EmbeddedBlockCoordinatorTests {

    /// Запись отложена: контейнер может доложить о смене слоя посреди прохода body, а менять
    /// состояние в этот момент нельзя. Записывается на витке планировщика — и ровно то, что доложено.
    @Test("Update writes on the scheduled turn, not synchronously")
    func updateWritesOnScheduledTurn() {
        guard #available(iOS 13.0, *) else { return }

        var written = [EmbeddedBlockPresentation]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            presentation: Binding(get: { EmbeddedBlockPresentation(layer: .placeholder, height: 104) },
                                  set: { written.append($0) }),
            creationHeight: 104,
            onLoad: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        let content = EmbeddedBlockPresentation(layer: .content, height: 104)
        coordinator.update(content)

        #expect(written.isEmpty)

        scheduled.forEach { $0() }

        #expect(written == [content])
    }

    /// Гонка демонтажа: запись уже в очереди, вью снимается с дерева до её исполнения. После
    /// `detach()` блок обязан промолчать — состояние снятой вью ему больше не принадлежит.
    @Test("Detach drops a write that was already scheduled")
    func detachDropsScheduledWrite() {
        guard #available(iOS 13.0, *) else { return }

        var written = [EmbeddedBlockPresentation]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            presentation: Binding(get: { EmbeddedBlockPresentation(layer: .placeholder, height: 104) },
                                  set: { written.append($0) }),
            creationHeight: 104,
            onLoad: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        coordinator.update(EmbeddedBlockPresentation(layer: .content, height: 104))
        coordinator.detach()

        scheduled.forEach { $0() }

        #expect(written.isEmpty)
    }
}
