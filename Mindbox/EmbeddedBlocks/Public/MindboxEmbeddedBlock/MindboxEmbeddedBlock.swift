//
//  MindboxEmbeddedBlock.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI wrapper over `MindboxEmbeddedBlockView`.
///
/// Created with the block `id` from the admin panel and the `height` the block should occupy.
/// Place it anywhere in a layout — the caller decides only the position and the width. The block
/// keeps the given height while its content is loading and shown; a block with nothing to show
/// collapses to zero height.
///
/// Both outcomes can be customized the same way as in UIKit, through modifiers on the block
/// itself: `placeholder` replaces the stock loading shimmer, and `errorView` opts into showing a
/// failure instead of collapsing. Both stay ordinary SwiftUI views drawn in place, so they see the
/// environment of the tree they were written in — objects, fonts, locale, color scheme.
///
/// ```swift
/// MindboxEmbeddedBlock(id: "stories", height: 104, onFail: hideSection)
///     .placeholder { StoriesSkeleton() }
///     .errorView { StoriesUnavailable() }
/// ```
///
/// Both modifiers return the block itself, so they come before any SwiftUI modifier: after
/// `.frame(…)` or `.padding(…)` the value is no longer a `MindboxEmbeddedBlock`.
///
/// A collapsed block is zero points tall, but a stack still pays its spacing around it. To hand the
/// space back completely, drop the whole section from the layout in `onFail` — as in the example
/// above.
@available(iOS 13.0, *)
public struct MindboxEmbeddedBlock: View {

    private let id: String
    private let height: CGFloat
    private let onLoad: (() -> Void)?
    private let onFail: (() -> Void)?

    private(set) var placeholderBuilder: (() -> AnyView)?
    private(set) var errorBuilder: (() -> AnyView)?

    /// - Parameters:
    ///   - id: The block id from the admin panel.
    ///   - height: The height the block occupies while loading and shown.
    ///   - onLoad: The block content is shown and the container is visible.
    ///   - onFail: The block cannot be shown — a failure or an empty block.
    public init(id: String,
                height: CGFloat,
                onLoad: (() -> Void)? = nil,
                onFail: (() -> Void)? = nil) {
        self.id = id
        self.height = height
        self.onLoad = onLoad
        self.onFail = onFail
    }

    /// Shows this view instead of the SDK shimmer while the block is loading.
    ///
    /// Called again, it replaces the previous placeholder.
    public func placeholder<Content: View>(@ViewBuilder _ build: @escaping () -> Content) -> Self {
        var block = self
        block.placeholderBuilder = { AnyView(build()) }
        return block
    }

    /// Shows this view instead of collapsing when the block cannot be shown.
    ///
    /// Applies only to failures: an empty block — one with nothing behind its id — always
    /// collapses, so a host cannot fill the space of a block that was never meant to be there.
    public func errorView<Content: View>(@ViewBuilder _ build: @escaping () -> Content) -> Self {
        var block = self
        block.errorBuilder = { AnyView(build()) }
        return block
    }

    public var body: some View {
        EmbeddedBlockBody(id: id,
                          height: height,
                          onLoad: onLoad,
                          onFail: onFail,
                          placeholder: placeholderBuilder,
                          errorContent: errorBuilder)
            .id(identity)
    }

    /// Идентичность блока в дереве SwiftUI.
    ///
    /// И `id`, и высоту контейнер получает при создании и потом не меняет, поэтому другое значение
    /// любого из них — это другой блок, который надо собрать заново, а не обновление текущего. Без
    /// этого хост, подставивший в блок другой id, продолжал бы видеть содержимое прежнего: SwiftUI
    /// переиспользовал бы уже созданный контейнер.
    var identity: Identity {
        Identity(id: id, height: height)
    }

    struct Identity: Hashable {
        let id: String
        let height: CGFloat
    }
}

/// Хранит текущий показ и рисует слои хоста поверх контейнера.
///
/// Отдельная вью, а не тело `MindboxEmbeddedBlock`: состояние обязано сбрасываться вместе с
/// контейнером при смене id или высоты, а сбрасывает его `.id(…)` — и только у той вью, к которой
/// применён.
@available(iOS 13.0, *)
private struct EmbeddedBlockBody: View {

    let id: String
    let height: CGFloat
    let onLoad: (() -> Void)?
    let onFail: (() -> Void)?
    let placeholder: (() -> AnyView)?
    let errorContent: (() -> AnyView)?

    /// Стартует с того же, с чего стартует контейнер: место занято, показан плейсхолдер. Блок
    /// занимает свою высоту сразу, а не с первого отчёта от контейнера.
    @State private var presentation: EmbeddedBlockPresentation

    init(id: String,
         height: CGFloat,
         onLoad: (() -> Void)?,
         onFail: (() -> Void)?,
         placeholder: (() -> AnyView)?,
         errorContent: (() -> AnyView)?) {
        self.id = id
        self.height = height
        self.onLoad = onLoad
        self.onFail = onFail
        self.placeholder = placeholder
        self.errorContent = errorContent
        _presentation = State(initialValue: EmbeddedBlockPresentation(layer: .placeholder,
                                                                     height: max(0, height)))
    }

    var body: some View {
        ZStack {
            EmbeddedBlockRepresentable(id: id,
                                       height: height,
                                       presentation: $presentation,
                                       onLoad: onLoad,
                                       onFail: onFail,
                                       hasPlaceholder: placeholder != nil,
                                       hasErrorView: errorContent != nil)
            hostLayer
        }
        .frame(height: presentation.height)
    }

    /// Слой хоста рисуется здесь, а не отдаётся контейнеру как `UIView` из `UIHostingController`:
    /// такой контроллер не входит в дерево SwiftUI, поэтому вью внутри него не видит его окружения —
    /// плейсхолдер с `@EnvironmentObject` просто падает, а заданные хостом шрифт, цвет и локаль до
    /// него не доезжают.
    @ViewBuilder private var hostLayer: some View {
        switch presentation.layer {
        case .placeholder:
            if let placeholder {
                placeholder()
            }
        case .errorView:
            if let errorContent {
                errorContent()
            }
        case .content, .nothing:
            EmptyView()
        }
    }
}

@available(iOS 13.0, *)
struct EmbeddedBlockRepresentable: UIViewRepresentable {

    let id: String
    let height: CGFloat

    @Binding var presentation: EmbeddedBlockPresentation

    let onLoad: (() -> Void)?
    let onFail: (() -> Void)?

    /// Есть ли у обёртки свой плейсхолдер и свой экран ошибки. Сами вью контейнеру не отдаются —
    /// только факт: под каждый заявленный слой он получает прозрачную заглушку, чтобы держать место
    /// и не рисовать своё, а красит это место SwiftUI поверх.
    let hasPlaceholder: Bool
    let hasErrorView: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(presentation: $presentation, onLoad: onLoad, onFail: onFail)
    }

    func makeUIView(context: Context) -> MindboxEmbeddedBlockView {
        let blockView = MindboxEmbeddedBlockView(id: id, height: height)
        let coordinator = context.coordinator
        blockView.delegate = coordinator
        blockView.onPresentationChange = { presentation in
            coordinator.update(presentation)
        }
        syncStandIns(in: blockView)
        return blockView
    }

    func updateUIView(_ uiView: MindboxEmbeddedBlockView, context: Context) {
        // Замыкания и биндинг захватываются заново на каждый проход body, поэтому координатор надо
        // переставлять на свежие, а не оставлять ему ту тройку, с которой его создали.
        let coordinator = context.coordinator
        coordinator.presentation = $presentation
        coordinator.onLoad = onLoad
        coordinator.onFail = onFail
        syncStandIns(in: uiView)
    }

    static func dismantleUIView(_ uiView: MindboxEmbeddedBlockView, coordinator: Coordinator) {
        // Вью ушла из дерева: докладывать о слоях и исходах некому, а состояние обёртки уже
        // выброшено вместе с ней.
        uiView.onPresentationChange = nil
        uiView.delegate = nil
    }

    /// Заглушки ставятся и снимаются на каждом обновлении, а не только при создании: модификатор мог
    /// быть применён по условию, поэтому слой может появиться после первого прохода — и точно так же
    /// исчезнуть, и тогда держать под него место больше не за что.
    func syncStandIns(in blockView: MindboxEmbeddedBlockView) {
        // Уже стоящую заглушку не подменяем: назначение нового вью пересобирало бы констрейнты
        // контейнера на каждом проходе body.
        if hasPlaceholder {
            if blockView.placeholderView == nil {
                blockView.placeholderView = Self.makeStandIn()
            }
        } else {
            blockView.placeholderView = nil
        }

        if hasErrorView {
            if blockView.errorView == nil {
                blockView.errorView = Self.makeStandIn()
            }
        } else {
            blockView.errorView = nil
        }
    }

    /// Прозрачная заглушка: контейнер держит под слой место, но ничего в нём не рисует и не
    /// перехватывает касания — и то и другое дело SwiftUI-слоя поверх.
    ///
    /// Размером она во весь контейнер: слои он прибивает к своим четырём краям сам. На что-то
    /// меньшее её не свести, да и незачем — пустой слой ничем не платит за свой размер.
    private static func makeStandIn() -> UIView {
        let standIn = UIView()
        standIn.backgroundColor = .clear
        standIn.isUserInteractionEnabled = false
        return standIn
    }

    final class Coordinator: MindboxEmbeddedBlockViewDelegate {

        var presentation: Binding<EmbeddedBlockPresentation>
        var onLoad: (() -> Void)?
        var onFail: (() -> Void)?

        init(presentation: Binding<EmbeddedBlockPresentation>,
             onLoad: (() -> Void)?,
             onFail: (() -> Void)?) {
            self.presentation = presentation
            self.onLoad = onLoad
            self.onFail = onFail
        }

        /// Пишется на следующем витке главной очереди: контейнер может доложить о смене слоя прямо
        /// посреди прохода body, а менять состояние в этот момент нельзя.
        func update(_ newPresentation: EmbeddedBlockPresentation) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.presentation.wrappedValue != newPresentation else { return }
                self.presentation.wrappedValue = newPresentation
            }
        }

        func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {
            onLoad?()
        }

        func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView) {
            onFail?()
        }
    }
}
#endif
