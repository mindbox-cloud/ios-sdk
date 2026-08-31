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
/// Created with the `placeSystemName` of the place from the admin panel and the `height` the
/// block should occupy.
/// Place it anywhere in a layout — the caller decides only the position and the width. The block
/// keeps the given height while its content is loading and shown; a block with nothing to show
/// collapses to zero height.
///
/// A different `placeSystemName` is a different block, built from scratch in place of the old one.
/// A different `height` resizes the block where it stands — the same content, no reload.
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
    ///   - placeSystemName: The system name of the place from the admin panel. Whitespace around
    ///     it is ignored; the name itself is matched as it is, case included.
    ///   - height: The height the block occupies while loading and shown. A new value resizes the
    ///     block in place, without reloading its content.
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
        // Normalized here too, so `.id(placeSystemName)` keeps one SwiftUI identity per place
        // however the name was padded.
        self.placeSystemName = MindboxEmbeddedBlockView.normalizedPlaceSystemName(placeSystemName)
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
        uiView.preferredHeight = height
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

        private var isDetached = false

        /// `DispatchQueue.main` outside tests.
        private let schedule: (@escaping () -> Void) -> Void

        init(appearance: Binding<MindboxEmbeddedBlockAppearance>,
             onLoad: (() -> Void)?,
             onFail: (() -> Void)?,
             schedule: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async { work() } }) {
            self.appearance = appearance
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
