//
//  MindboxEmbeddedBlockTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

#if canImport(SwiftUI)
import Testing
import SwiftUI
@testable import Mindbox

/// Логика блока живёт в UIKit-контейнере, поэтому здесь проверяется только то, что есть у
/// SwiftUI-обёртки своего: контракт модификаторов, идентичность блока в дереве и то, как обёртка
/// настраивает контейнер под слои, которые рисует сама.
@Suite("MindboxEmbeddedBlock SwiftUI wrapper", .tags(.embeddedBlocks))
@MainActor
struct MindboxEmbeddedBlockTests {

    // MARK: - Modifiers

    /// Контракт модификаторов держится на семантике значения: модификатор обязан вернуть новый блок,
    /// а не изменить тот, к которому его применили, иначе один и тот же блок, переиспользованный в
    /// вёрстке с разной отделкой, тащил бы за собой чужой плейсхолдер.
    @Test("Bare block has neither a placeholder nor an error view")
    func bareBlockHasNoCustomViews() {
        let block = MindboxEmbeddedBlock(id: "stories", height: 104)

        #expect(block.placeholderBuilder == nil)
        #expect(block.errorBuilder == nil)
    }

    @Test("Placeholder modifier sets the placeholder and leaves the error view alone")
    func placeholderModifierSetsOnlyThePlaceholder() {
        let block = MindboxEmbeddedBlock(id: "stories", height: 104)
            .placeholder { Color.gray }

        #expect(block.placeholderBuilder != nil)
        #expect(block.errorBuilder == nil)
    }

    @Test("Error view modifier sets the error view and leaves the placeholder alone")
    func errorViewModifierSetsOnlyTheErrorView() {
        let block = MindboxEmbeddedBlock(id: "stories", height: 104)
            .errorView { Text("no stories") }

        #expect(block.errorBuilder != nil)
        #expect(block.placeholderBuilder == nil)
    }

    @Test("Both modifiers compose in either order")
    func bothModifiersCompose() {
        let placeholderFirst = MindboxEmbeddedBlock(id: "stories", height: 104)
            .placeholder { Color.gray }
            .errorView { Text("no stories") }

        let errorFirst = MindboxEmbeddedBlock(id: "stories", height: 104)
            .errorView { Text("no stories") }
            .placeholder { Color.gray }

        #expect(placeholderFirst.placeholderBuilder != nil)
        #expect(placeholderFirst.errorBuilder != nil)
        #expect(errorFirst.placeholderBuilder != nil)
        #expect(errorFirst.errorBuilder != nil)
    }

    @Test("Modifier returns a copy and does not touch the block it was applied to")
    func modifierDoesNotMutateTheOriginal() {
        let bare = MindboxEmbeddedBlock(id: "stories", height: 104)

        let decorated = bare
            .placeholder { Color.gray }
            .errorView { Text("no stories") }

        #expect(bare.placeholderBuilder == nil)
        #expect(bare.errorBuilder == nil)
        #expect(decorated.placeholderBuilder != nil)
        #expect(decorated.errorBuilder != nil)
    }

    @Test("Applying a modifier twice keeps the last view")
    func repeatedModifierKeepsTheLastView() {
        let log = BuildLog()

        let block = MindboxEmbeddedBlock(id: "stories", height: 104)
            .placeholder { ProbeView("first", log: log) }
            .placeholder { ProbeView("second", log: log) }

        _ = block.placeholderBuilder?()

        #expect(log.tags == ["second"])
    }

    /// Отделка не меняет блок: обёртка может украсить один и тот же блок по-разному, но контейнер
    /// под ней остаётся тем же и не должен пересобираться.
    @Test("Modifiers do not change the block identity")
    func modifiersKeepTheIdentity() {
        let bare = MindboxEmbeddedBlock(id: "stories", height: 104)

        let decorated = bare.placeholder { Color.gray }

        #expect(decorated.identity == bare.identity)
    }

    // MARK: - Identity

    /// `id` контейнер получает при создании и потом не меняет, поэтому другой id — это другой блок.
    /// Без смены идентичности SwiftUI переиспользовал бы прежний контейнер, и хост продолжал бы
    /// видеть содержимое старого блока.
    @Test("Another id is another block")
    func identityChangesWithTheId() {
        let stories = MindboxEmbeddedBlock(id: "stories", height: 104)
        let banner = MindboxEmbeddedBlock(id: "banner", height: 104)

        #expect(stories.identity != banner.identity)
    }

    /// Высоту контейнер тоже получает при создании — новая высота требует нового контейнера.
    @Test("Another height is another block")
    func identityChangesWithTheHeight() {
        let short = MindboxEmbeddedBlock(id: "stories", height: 104)
        let tall = MindboxEmbeddedBlock(id: "stories", height: 208)

        #expect(short.identity != tall.identity)
    }

    /// Обратная сторона: блок, у которого id и высота те же, пересобираться не должен — иначе
    /// содержимое перезагружалось бы на каждое обновление вёрстки хоста.
    @Test("Same id and height keep the same block")
    func identityIsStableForTheSameInputs() {
        let withCallback = MindboxEmbeddedBlock(id: "stories", height: 104, onLoad: {})
        let withoutCallback = MindboxEmbeddedBlock(id: "stories", height: 104)

        #expect(withCallback.identity == withoutCallback.identity)
    }

    // MARK: - Host layers

    /// Свой плейсхолдер обёртка рисует сама, поэтому контейнеру достаётся прозрачная заглушка: иначе
    /// под плейсхолдером хоста остался бы виден шиммер SDK.
    @Test("Custom placeholder replaces the SDK shimmer with a transparent stand-in")
    func customPlaceholderReplacesTheShimmer() throws {
        let blockView = makeBlockView()

        makeRepresentable(hasPlaceholder: true).syncStandIns(in: blockView)

        let standIn = try #require(blockView.placeholderView)
        #expect(standIn.superview === blockView)
        #expect(blockView.subviews.contains { $0 is EmbeddedBlockShimmerView } == false)
        // Касания достаются SwiftUI-слою поверх, а не заглушке под ним.
        #expect(standIn.isUserInteractionEnabled == false)
    }

    @Test("Block without a custom placeholder keeps the SDK shimmer")
    func bareBlockKeepsTheShimmer() {
        let blockView = makeBlockView()

        makeRepresentable().syncStandIns(in: blockView)

        #expect(blockView.placeholderView == nil)
        #expect(blockView.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    /// Держать высоту на провале контейнер соглашается только по назначенному `errorView`, поэтому
    /// заглушка нужна и здесь — иначе SwiftUI-экран ошибки рисовался бы в схлопнутом блоке.
    @Test("Custom error view opts the container into showing the failure")
    func customErrorViewOptsIntoShowingTheFailure() {
        let blockView = makeBlockView()

        makeRepresentable(hasErrorView: true).syncStandIns(in: blockView)

        #expect(blockView.errorView != nil)
    }

    @Test("Block without a custom error view leaves the container collapsing")
    func bareBlockLeavesTheContainerCollapsing() {
        let blockView = makeBlockView()

        makeRepresentable().syncStandIns(in: blockView)

        #expect(blockView.errorView == nil)
    }

    /// Модификатор мог быть применён по условию: слой, появившийся после создания блока, обязан
    /// доехать до контейнера, а исчезнувший — перестать держать под себя место.
    @Test("Layers added and dropped after creation take effect")
    func layersAddedAndDroppedAfterCreationTakeEffect() {
        let blockView = makeBlockView()
        makeRepresentable().syncStandIns(in: blockView)

        makeRepresentable(hasPlaceholder: true, hasErrorView: true).syncStandIns(in: blockView)

        #expect(blockView.placeholderView != nil)
        #expect(blockView.errorView != nil)

        makeRepresentable().syncStandIns(in: blockView)

        #expect(blockView.placeholderView == nil)
        #expect(blockView.errorView == nil)
    }

    /// Обновление без изменений не должно стоить контейнеру пересборки слоёв и констрейнтов:
    /// `updateUIView` вызывается на каждый проход body хоста.
    @Test("Repeated updates keep the very same stand-ins")
    func repeatedUpdatesKeepTheSameStandIns() throws {
        let blockView = makeBlockView()
        let representable = makeRepresentable(hasPlaceholder: true, hasErrorView: true)
        representable.syncStandIns(in: blockView)
        let placeholder = try #require(blockView.placeholderView)
        let errorView = try #require(blockView.errorView)

        representable.syncStandIns(in: blockView)

        #expect(blockView.placeholderView === placeholder)
        #expect(blockView.errorView === errorView)
    }

    // MARK: - Helpers

    /// Контейнер с подменёнными зависимостями: обёртка сама ничего не грузит, её дело — правильно
    /// настроить контейнер, поэтому окно и живой контент здесь не нужны.
    private func makeBlockView() -> MindboxEmbeddedBlockView {
        MindboxEmbeddedBlockView(id: "stories",
                                 height: 104,
                                 contentProvider: EmbeddedBlockTestBed().provider)
    }

    private func makeRepresentable(hasPlaceholder: Bool = false,
                                   hasErrorView: Bool = false) -> EmbeddedBlockRepresentable {
        let presentation = EmbeddedBlockPresentation(layer: .placeholder, height: 104)
        return EmbeddedBlockRepresentable(id: "stories",
                                          height: 104,
                                          presentation: .constant(presentation),
                                          onLoad: nil,
                                          onFail: nil,
                                          hasPlaceholder: hasPlaceholder,
                                          hasErrorView: hasErrorView)
    }
}

/// Какие вью на самом деле собрал блок. `AnyView` снаружи не разглядеть, поэтому отметку оставляет
/// сама вью в момент создания.
private final class BuildLog {
    var tags: [String] = []
}

private struct ProbeView: View {

    init(_ tag: String, log: BuildLog) {
        log.tags.append(tag)
    }

    var body: some View { Color.clear }
}
#endif
