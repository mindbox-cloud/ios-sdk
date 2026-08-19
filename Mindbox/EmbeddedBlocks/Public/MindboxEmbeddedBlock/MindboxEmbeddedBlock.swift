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
/// Created with the `placeSystemName` of the place from the admin panel and the `height` the
/// block should occupy.
/// Place it anywhere in a layout — the caller decides only the position and the width. The block
/// keeps the given height while its content is loading and shown; a block with nothing to show
/// collapses to zero height.
///
/// Both values are fixed at creation. A different `placeSystemName` is a different block, built
/// from scratch in place of the old one. A different `height` changes nothing: the block keeps the height it was
/// created with and reports the ignored value to the log.
///
/// Both outcomes can be customized the same way as in UIKit, through modifiers on the block
/// itself: `placeholder` replaces the stock loading shimmer, and `errorView` opts into showing a
/// failure instead of collapsing. Both stay ordinary SwiftUI views drawn in place, so they see the
/// environment of the tree they were written in — objects, fonts, locale, color scheme.
///
/// ```swift
/// MindboxEmbeddedBlock(placeSystemName: "stories", height: 104, onFail: hideSection)
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

    private let placeSystemName: String
    private let height: CGFloat
    private let timeout: TimeInterval?
    private let onLoad: (() -> Void)?
    private let onFail: (() -> Void)?

    private(set) var placeholderBuilder: (() -> AnyView)?
    private(set) var errorBuilder: (() -> AnyView)?

    /// - Parameters:
    ///   - placeSystemName: The system name of the place from the admin panel.
    ///   - height: The height the block occupies while loading and shown. Fixed at creation:
    ///     a new value given to a live block is ignored.
    ///   - timeout: How long the block waits to learn what it shows before collapsing as
    ///     empty, in seconds. `nil` means the SDK default of 30. An answer that arrives after that
    ///     no longer expands the block; the next attempt starts when the block enters the window
    ///     again.
    ///   - onLoad: The block content is shown and the container is visible.
    ///   - onFail: The block cannot be shown — a failure or an empty block.
    public init(placeSystemName: String,
                height: CGFloat,
                timeout: TimeInterval? = nil,
                onLoad: (() -> Void)? = nil,
                onFail: (() -> Void)? = nil) {
        self.placeSystemName = placeSystemName
        self.height = height
        self.timeout = timeout
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
    /// Applies only to failures: an empty block — one with nothing behind its place system name — always
    /// collapses, so a host cannot fill the space of a block that was never meant to be there.
    public func errorView<Content: View>(@ViewBuilder _ build: @escaping () -> Content) -> Self {
        var block = self
        block.errorBuilder = { AnyView(build()) }
        return block
    }

    public var body: some View {
        EmbeddedBlockBody(placeSystemName: placeSystemName,
                          height: height,
                          timeout: timeout,
                          onLoad: onLoad,
                          onFail: onFail,
                          placeholder: placeholderBuilder,
                          errorContent: errorBuilder)
            .id(placeSystemName)
    }
}

@available(iOS 13.0, *)
private struct EmbeddedBlockBody: View {

    let placeSystemName: String
    let height: CGFloat
    let timeout: TimeInterval?
    let onLoad: (() -> Void)?
    let onFail: (() -> Void)?
    let placeholder: (() -> AnyView)?
    let errorContent: (() -> AnyView)?

    /// Starts from the same point the container starts from: the space is taken, the placeholder
    /// is shown. The block occupies its height right away, not from the container's first report.
    @State private var appearance: MindboxEmbeddedBlockAppearance

    init(placeSystemName: String,
         height: CGFloat,
         timeout: TimeInterval?,
         onLoad: (() -> Void)?,
         onFail: (() -> Void)?,
         placeholder: (() -> AnyView)?,
         errorContent: (() -> AnyView)?) {
        self.placeSystemName = placeSystemName
        self.height = height
        self.timeout = timeout
        self.onLoad = onLoad
        self.onFail = onFail
        self.placeholder = placeholder
        self.errorContent = errorContent
        _appearance = State(initialValue: .placeholder)
    }

    var body: some View {
        ZStack {
            EmbeddedBlockRepresentable(placeSystemName: placeSystemName,
                                       height: height,
                                       timeout: timeout,
                                       appearance: $appearance,
                                       onLoad: onLoad,
                                       onFail: onFail,
                                       hasPlaceholder: placeholder != nil,
                                       hasErrorView: errorContent != nil)
            hostLayer
        }
        // The container gives the height to a UIKit host through `intrinsicContentSize`, which SwiftUI
        // does not read: here the same rule is applied to the frame instead.
        .frame(height: appearance == .collapsed ? 0 : max(0, height))
    }

    @ViewBuilder private var hostLayer: some View {
        switch appearance {
        case .placeholder:
            if let placeholder {
                placeholder()
            }
        case .error:
            if let errorContent {
                errorContent()
            }
        case .content, .collapsed:
            EmptyView()
        }
    }
}

@available(iOS 13.0, *)
struct EmbeddedBlockRepresentable: UIViewRepresentable {

    let placeSystemName: String
    let height: CGFloat
    let timeout: TimeInterval?

    @Binding var appearance: MindboxEmbeddedBlockAppearance

    let onLoad: (() -> Void)?
    let onFail: (() -> Void)?

    let hasPlaceholder: Bool
    let hasErrorView: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(appearance: $appearance,
                    creationHeight: height,
                    onLoad: onLoad,
                    onFail: onFail)
    }

    func makeUIView(context: Context) -> MindboxEmbeddedBlockView {
        let blockView = MindboxEmbeddedBlockView(placeSystemName: placeSystemName, height: height, timeout: timeout)
        let coordinator = context.coordinator
        blockView.delegate = coordinator
        blockView.setAppearanceObserver { appearance in
            coordinator.update(appearance)
        }
        syncStandIns(in: blockView)
        return blockView
    }

    func updateUIView(_ uiView: MindboxEmbeddedBlockView, context: Context) {
        let coordinator = context.coordinator
        coordinator.appearance = $appearance
        coordinator.onLoad = onLoad
        coordinator.onFail = onFail
        coordinator.warnIfHeightIsIgnored(height, placeSystemName: placeSystemName)
        syncStandIns(in: uiView)
    }

    static func dismantleUIView(_ uiView: MindboxEmbeddedBlockView, coordinator: Coordinator) {
        uiView.setAppearanceObserver(nil)
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

        var appearance: Binding<MindboxEmbeddedBlockAppearance>
        var onLoad: (() -> Void)?
        var onFail: (() -> Void)?

        private let creationHeight: CGFloat

        private var hasWarnedAboutIgnoredHeight = false

        private var isDetached = false

        /// `DispatchQueue.main` outside tests.
        private let schedule: (@escaping () -> Void) -> Void

        init(appearance: Binding<MindboxEmbeddedBlockAppearance>,
             creationHeight: CGFloat,
             onLoad: (() -> Void)?,
             onFail: (() -> Void)?,
             schedule: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async { work() } }) {
            self.appearance = appearance
            self.creationHeight = creationHeight
            self.onLoad = onLoad
            self.onFail = onFail
            self.schedule = schedule
        }

        func update(_ newAppearance: MindboxEmbeddedBlockAppearance) {
            schedule { [weak self] in
                guard let self, !self.isDetached,
                      self.appearance.wrappedValue != newAppearance else { return }
                self.appearance.wrappedValue = newAppearance
            }
        }

        /// An ignored height has no other symptom.
        func warnIfHeightIsIgnored(_ newHeight: CGFloat, placeSystemName: String) {
            guard !hasWarnedAboutIgnoredHeight, newHeight != creationHeight else { return }

            hasWarnedAboutIgnoredHeight = true
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given height \(newHeight) after creation and keeps \(creationHeight): the height is fixed when the block is created.",
                          level: .error,
                          category: .embeddedBlocks)
        }

        /// Silences the write `update` has already queued: `weak self` is no guarantee — when
        /// SwiftUI releases the coordinator after dismantling is unspecified.
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
