//
//  MindboxEmbeddedBlock.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI
import MindboxLogger

/// SwiftUI wrapper over `MindboxEmbeddedBlockView`.
///
/// Created with the block `id` from the admin panel and the `height` the block should occupy.
/// Place it anywhere in a layout — the caller decides only the position and the width. The block
/// keeps the given height while its content is loading and shown; a block with nothing to show
/// collapses to zero height.
///
/// Both values are fixed at creation. A different `id` is a different block, built from scratch in
/// place of the old one. A different `height` changes nothing: the block keeps the height it was
/// created with and reports the ignored value to the log.
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
    ///   - height: The height the block occupies while loading and shown. Fixed at creation:
    ///     a new value given to a live block is ignored.
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
            .id(id)
    }
}

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

    let hasPlaceholder: Bool
    let hasErrorView: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(presentation: $presentation,
                    creationHeight: height,
                    onLoad: onLoad,
                    onFail: onFail)
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
        let coordinator = context.coordinator
        coordinator.presentation = $presentation
        coordinator.onLoad = onLoad
        coordinator.onFail = onFail
        syncStandIns(in: uiView)
    }

    static func dismantleUIView(_ uiView: MindboxEmbeddedBlockView, coordinator: Coordinator) {
        uiView.onPresentationChange = nil
        uiView.delegate = nil
        coordinator.detach()
    }

    func syncStandIns(in blockView: MindboxEmbeddedBlockView) {
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

        private let creationHeight: CGFloat

        private var hasWarnedAboutIgnoredHeight = false

        private var isDetached = false

        /// Куда `update` откладывает запись — `DispatchQueue.main` вне тестов.
        private let schedule: (@escaping () -> Void) -> Void

        init(presentation: Binding<EmbeddedBlockPresentation>,
             creationHeight: CGFloat,
             onLoad: (() -> Void)?,
             onFail: (() -> Void)?,
             schedule: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async { work() } }) {
            self.presentation = presentation
            self.creationHeight = creationHeight
            self.onLoad = onLoad
            self.onFail = onFail
            self.schedule = schedule
        }

        func update(_ newPresentation: EmbeddedBlockPresentation) {
            schedule { [weak self] in
                guard let self, !self.isDetached,
                      self.presentation.wrappedValue != newPresentation else { return }
                self.presentation.wrappedValue = newPresentation
            }
        }

        /// Вью снята с дерева: гасит запись, уже поставленную `update` в очередь, — обнуление
        /// колбэков в `dismantleUIView` её не отзывает, а `weak self` не гарантия: когда SwiftUI
        /// отпустит координатор после демонтажа, не специфицировано.
        func detach() {
            isDetached = true
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
