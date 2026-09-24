//
//  MindboxEmbeddedBlock.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI
import UIKit

/// SwiftUI wrapper over `MindboxEmbeddedBlockView`.
///
/// Created with the `placeSystemName` of the place from the admin panel and the `height` the
/// block should occupy.
/// Place it anywhere in a layout — the caller decides only the position and the width. The block
/// keeps the given height while its content is loading and shown; a block with nothing to show
/// collapses to zero height. What the block shows before the SDK answers is decided by
/// `loadingStrategy`: a placeholder, nothing, or — by default — nothing until the place has shown
/// content once on this device and a placeholder from then on. The first look is known before the
/// first frame, so a block that waits hidden never flashes reserved space.
///
/// A different `placeSystemName` is a different block, built from scratch in place of the old one.
/// A different `height` resizes the block where it stands — the same content, no reload. The
/// strategy and `animatesReveal` are read once, when the block is created.
///
/// Both looks can be customized the same way as in UIKit, through modifiers on the block
/// itself: `placeholder` replaces the stock loading shimmer, and `errorView` opts into showing a
/// failure instead of collapsing. Both stay ordinary SwiftUI views drawn in place, so they see the
/// environment of the tree they were written in — objects, fonts, locale, color scheme.
///
/// The outcome arrives through three closures: `onLoad` when the content is shown, `onEmpty` when
/// there is nothing to show at the place, and `onFail` with a reason when the block could not be
/// shown.
///
/// ```swift
/// MindboxEmbeddedBlock(placeSystemName: "stories", height: 104,
///                      loadingStrategy: .hidden,
///                      onEmpty: hideSection,
///                      onFail: { reason in log("stories failed: \(reason)") })
///     .placeholder { StoriesSkeleton() }
///     .errorView { StoriesUnavailable() }
/// ```
///
/// Both modifiers return the block itself, so they come before any SwiftUI modifier: after
/// `.frame(…)` or `.padding(…)` the value is no longer a `MindboxEmbeddedBlock`.
///
/// A collapsed block is zero points tall, but a stack still pays its spacing around it. To hand the
/// space back completely, drop the whole section from the layout in `onEmpty` — as in the example
/// above — and in `onFail` when no `errorView` is set.
@available(iOS 13.0, *)
public struct MindboxEmbeddedBlock: View {

    private let placeSystemName: String
    private let height: CGFloat
    private let timeout: TimeInterval?
    private let loadingStrategy: MindboxEmbeddedBlockLoadingStrategy
    private let animatesReveal: Bool
    private let onLoad: (() -> Void)?
    private let onEmpty: (() -> Void)?
    private let onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

    private(set) var placeholderBuilder: (() -> AnyView)?
    private(set) var errorBuilder: (() -> AnyView)?

    /// - Parameters:
    ///   - placeSystemName: The system name of the place from the admin panel. Whitespace around
    ///     it is ignored; the name itself is matched as it is, case included.
    ///   - height: The height the block occupies while loading and shown. A new value resizes the
    ///     block in place, without reloading its content.
    ///   - timeout: How long the block waits to learn what it shows before failing as
    ///     `networkError`, in seconds. `nil` means the SDK default of 30. An answer that arrives after
    ///     that no longer expands the block; the next attempt starts when the block enters the
    ///     window again.
    ///   - loadingStrategy: What the block shows until the SDK answers. `automatic` — the default —
    ///     keeps the block hidden until the place has shown content once on this device and puts a
    ///     placeholder there from then on. Read once, when the block is created.
    ///   - animatesReveal: Whether the SDK animates the reveal of the content — a fade, and the
    ///     growth of a block that waited hidden. `true` by default. Turn it off to animate the
    ///     block's container yourself in `onLoad`. Read once, when the block is created.
    ///   - onLoad: The block content is shown and the container is visible.
    ///   - onEmpty: There is nothing to show at the place — no campaign, targeting or A/B group not
    ///     matched, show budget spent, or the page rendered nothing. The block collapses; `errorView`
    ///     does not apply.
    ///   - onFail: The block could not be shown. The block collapses or shows `errorView` — unless it
    ///     waited hidden: a block that never took its space does not take it for an error screen. The
    ///     reason is for logs and analytics — match it with a `default`, a later SDK may add reasons.
    public init(placeSystemName: String,
                height: CGFloat,
                timeout: TimeInterval? = nil,
                loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic,
                animatesReveal: Bool = true,
                onLoad: (() -> Void)? = nil,
                onEmpty: (() -> Void)? = nil,
                onFail: ((MindboxEmbeddedBlockFailReason) -> Void)? = nil) {
        // Normalized here too, so `.id(placeSystemName)` keeps one SwiftUI identity per place
        // however the name was padded.
        self.placeSystemName = MindboxEmbeddedBlockView.normalizedPlaceSystemName(placeSystemName)
        self.height = height
        self.timeout = timeout
        self.loadingStrategy = loadingStrategy
        self.animatesReveal = animatesReveal
        self.onLoad = onLoad
        self.onEmpty = onEmpty
        self.onFail = onFail
    }

    /// Shows this view instead of the SDK shimmer while the block is loading.
    ///
    /// Called again, it replaces the previous placeholder. A block that waits hidden shows neither.
    public func placeholder<Content: View>(@ViewBuilder _ build: @escaping () -> Content) -> Self {
        var block = self
        block.placeholderBuilder = { AnyView(build()) }
        return block
    }

    /// Shows this view instead of collapsing when the block cannot be shown.
    ///
    /// Applies only to failures: an empty block — one with nothing behind its place system name — always
    /// collapses, so a host cannot fill the space of a block that was never meant to be there. A block
    /// that waited hidden stays hidden on a failure for the same reason.
    public func errorView<Content: View>(@ViewBuilder _ build: @escaping () -> Content) -> Self {
        var block = self
        block.errorBuilder = { AnyView(build()) }
        return block
    }

    public var body: some View {
        EmbeddedBlockBody(placeSystemName: placeSystemName,
                          height: height,
                          timeout: timeout,
                          loadingStrategy: loadingStrategy,
                          animatesReveal: animatesReveal,
                          // Decided here, before the first frame: the body's state starts from it, so a
                          // hidden block is zero points tall from its very first layout.
                          initialAppearance: MindboxEmbeddedBlockView.initialAppearance(placeSystemName: placeSystemName,
                                                                                        loadingStrategy: loadingStrategy),
                          onLoad: onLoad,
                          onEmpty: onEmpty,
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
    let loadingStrategy: MindboxEmbeddedBlockLoadingStrategy
    let animatesReveal: Bool
    let onLoad: (() -> Void)?
    let onEmpty: (() -> Void)?
    let onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?
    let placeholder: (() -> AnyView)?
    let errorContent: (() -> AnyView)?

    @State private var appearance: MindboxEmbeddedBlockAppearance

    init(placeSystemName: String,
         height: CGFloat,
         timeout: TimeInterval?,
         loadingStrategy: MindboxEmbeddedBlockLoadingStrategy,
         animatesReveal: Bool,
         initialAppearance: MindboxEmbeddedBlockAppearance,
         onLoad: (() -> Void)?,
         onEmpty: (() -> Void)?,
         onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?,
         placeholder: (() -> AnyView)?,
         errorContent: (() -> AnyView)?) {
        self.placeSystemName = placeSystemName
        self.height = height
        self.timeout = timeout
        self.loadingStrategy = loadingStrategy
        self.animatesReveal = animatesReveal
        self.onLoad = onLoad
        self.onEmpty = onEmpty
        self.onFail = onFail
        self.placeholder = placeholder
        self.errorContent = errorContent
        _appearance = State(initialValue: initialAppearance)
    }

    var body: some View {
        ZStack {
            EmbeddedBlockRepresentable(placeSystemName: placeSystemName,
                                       height: height,
                                       timeout: timeout,
                                       loadingStrategy: loadingStrategy,
                                       animatesReveal: animatesReveal,
                                       appearance: $appearance,
                                       onLoad: onLoad,
                                       onEmpty: onEmpty,
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
    let loadingStrategy: MindboxEmbeddedBlockLoadingStrategy
    let animatesReveal: Bool

    @Binding var appearance: MindboxEmbeddedBlockAppearance

    let onLoad: (() -> Void)?
    let onEmpty: (() -> Void)?
    let onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

    let hasPlaceholder: Bool
    let hasErrorView: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(appearance: $appearance,
                    onLoad: onLoad,
                    onEmpty: onEmpty,
                    onFail: onFail,
                    animatesReveal: animatesReveal)
    }

    func makeUIView(context: Context) -> MindboxEmbeddedBlockView {
        let blockView = MindboxEmbeddedBlockView(placeSystemName: placeSystemName,
                                                 height: height,
                                                 timeout: timeout,
                                                 loadingStrategy: loadingStrategy,
                                                 animatesReveal: animatesReveal)
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
        coordinator.onEmpty = onEmpty
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
        var onEmpty: (() -> Void)?
        var onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

        /// The wrapper owns the block's frame, so the growth of a block that waited hidden is its
        /// animation to run; the container fades the content in on its own.
        let animatesReveal: Bool

        private var isDetached = false

        /// `DispatchQueue.main` outside tests.
        private let schedule: (@escaping () -> Void) -> Void

        /// `withAnimation` outside tests — unless the user asked the system to reduce motion.
        private let animateReveal: (@escaping () -> Void) -> Void

        init(appearance: Binding<MindboxEmbeddedBlockAppearance>,
             onLoad: (() -> Void)?,
             onEmpty: (() -> Void)?,
             onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?,
             animatesReveal: Bool = true,
             schedule: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async { work() } },
             animateReveal: @escaping (@escaping () -> Void) -> Void = { changes in
                 guard !UIAccessibility.isReduceMotionEnabled else {
                     changes()
                     return
                 }

                 withAnimation(.easeInOut(duration: Constants.EmbeddedBlock.revealAnimationDuration)) { changes() }
             }) {
            self.appearance = appearance
            self.onLoad = onLoad
            self.onEmpty = onEmpty
            self.onFail = onFail
            self.animatesReveal = animatesReveal
            self.schedule = schedule
            self.animateReveal = animateReveal
        }

        func update(_ newAppearance: MindboxEmbeddedBlockAppearance) {
            schedule { [weak self] in
                guard let self, !self.isDetached,
                      self.appearance.wrappedValue != newAppearance else { return }

                let write = { self.appearance.wrappedValue = newAppearance }

                // Only the arrival of content is a reveal; a collapse or an error screen lands at once.
                if newAppearance == .content, self.animatesReveal {
                    self.animateReveal(write)
                } else {
                    write()
                }
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

        func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {
            onEmpty?()
        }

        func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                             reason: MindboxEmbeddedBlockFailReason) {
            onFail?(reason)
        }
    }
}
#endif
