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
/// takes the given height when its content is shown; a block with nothing to show collapses to
/// zero height. Whether it takes that height while the content is loading is decided by
/// `loadingStrategy`: a placeholder, nothing, or — by default — nothing until the place has shown
/// content once on this device and a placeholder from then on. The first look is known before the
/// first frame, so a block that waits hidden never flashes reserved space.
///
/// A different place is a different block, built from scratch in place of the old one; a
/// `placeSystemName` that differs only in padding or letter case is the same place and the same block.
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
///                      loadingStrategy: .automatic,
///                      onEmpty: hideSection,
///                      onFail: { reason in log("stories failed: \(reason)") })
/// ```
///
/// Both modifiers return the block itself, so they come before any SwiftUI modifier: after
/// `.frame(…)` or `.padding(…)` the value is no longer a `MindboxEmbeddedBlock`. Neither shows until
/// the block has taken its place: with `hidden`, or `automatic` at a place with no record yet, the
/// first wait and a failure on it show nothing. Once content was shown, the block waits in the
/// `placeholder` while its page is replaced and shows the `errorView` on a failure.
///
/// A collapsed block is zero points tall, but a stack still pays its spacing around it. To hand the
/// space back completely, drop the whole section from the layout in `onEmpty` — as in the example
/// above — and in `onFail` when no `errorView` is set.
@available(iOS 13.0, *)
public struct MindboxEmbeddedBlock: View {

    private let placeSystemName: String
    private let height: CGFloat
    private let timeout: TimeInterval?

    /// What the block shows until the SDK answers, given at creation. See `MindboxEmbeddedBlockLoadingStrategy`.
    public let loadingStrategy: MindboxEmbeddedBlockLoadingStrategy

    /// Whether the SDK animates the reveal of the content, given at creation. The system's Reduce
    /// Motion setting turns the animation off as well.
    public let animatesReveal: Bool

    private let onLoad: (() -> Void)?
    private let onEmpty: (() -> Void)?
    private let onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

    private(set) var placeholderBuilder: (() -> AnyView)?
    private(set) var errorBuilder: (() -> AnyView)?

    /// - Parameters:
    ///   - placeSystemName: The system name of the place from the admin panel. Matched with the
    ///     surrounding whitespace trimmed and the letter case ignored, the way an operation system
    ///     name is: `Main-Screen-Top` and `main-screen-top` are the same place.
    ///   - height: The height the block occupies when shown — and while loading, unless it waits
    ///     hidden by its `loadingStrategy`. A new value resizes the block in place, without
    ///     reloading its content.
    ///   - loadingStrategy: What the block shows until the SDK answers: a placeholder, nothing, or
    ///     `automatic` — the default — hidden until the place has shown content once on this device
    ///     and a placeholder from then on. Read once, when the block is created.
    ///   - timeout: How long the block waits to learn what it shows before failing as
    ///     `networkError`, in seconds; `errorView` applies unless the block waited hidden. `nil`
    ///     means the SDK default of 30. An answer that arrives after
    ///     that no longer expands the block; the next attempt starts when the block enters the
    ///     window again.
    ///   - animatesReveal: Whether the SDK animates the reveal of the content — a fade, and the
    ///     growth of a block that waited hidden. `true` by default; the system's Reduce Motion
    ///     setting turns the animation off as well. Turn it off to animate the block's container
    ///     yourself in `onLoad`. Read once, when the block is created.
    ///   - onLoad: The block content is shown and the container is visible. A block that waited
    ///     hidden grows from 0 to `height` here; a `List` row that holds it changes its height on
    ///     this call.
    ///   - onEmpty: There is nothing to show at the place — no campaign, targeting or A/B group not
    ///     matched, show budget spent, or the page rendered nothing. The block collapses; `errorView`
    ///     does not apply.
    ///   - onFail: The block could not be shown. The block collapses or shows `errorView` — unless it
    ///     waited hidden: a block that never took its space does not take it for an error screen. The
    ///     reason is for logs and analytics — match it with a `default`, a later SDK may add reasons.
    public init(placeSystemName: String,
                height: CGFloat,
                loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic,
                timeout: TimeInterval? = nil,
                animatesReveal: Bool = true,
                onLoad: (() -> Void)? = nil,
                onEmpty: (() -> Void)? = nil,
                onFail: ((MindboxEmbeddedBlockFailReason) -> Void)? = nil) {
        // Normalized here too, so the view below gets the name the way the UIKit init would.
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
    /// Called again, it replaces the previous placeholder. A block that waits hidden shows neither
    /// until it has shown content; from then on it keeps its space in the placeholder while its
    /// page is replaced.
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
                          onLoad: onLoad,
                          onEmpty: onEmpty,
                          onFail: onFail,
                          placeholder: placeholderBuilder,
                          errorContent: errorBuilder)
            // One SwiftUI identity per place, however the name was padded or cased: `Stories` and
            // `stories` are the same place to the SDK, so they are the same block here.
            .id(MindboxEmbeddedBlockView.placeKey(placeSystemName))
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

    /// What the container reported, once it exists. Until then the look is the first look — read
    /// here, when the body is first built, and not when the block value is created: a value is
    /// made on every pass of its parent's body, and may be made before the SDK is initialized.
    @State private var appearance: MindboxEmbeddedBlockAppearance?

    /// The first look is known before the first frame, so a block that waits hidden is zero points
    /// tall from its very first layout.
    private var shownAppearance: MindboxEmbeddedBlockAppearance {
        appearance ?? MindboxEmbeddedBlockView.initialAppearance(placeSystemName: placeSystemName,
                                                                 loadingStrategy: loadingStrategy)
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
        .frame(height: shownAppearance == .collapsed ? 0 : max(0, height))
    }

    @ViewBuilder private var hostLayer: some View {
        switch shownAppearance {
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

    /// `nil` until the container has reported anything: the body then shows the first look.
    @Binding var appearance: MindboxEmbeddedBlockAppearance?

    let onLoad: (() -> Void)?
    let onEmpty: (() -> Void)?
    let onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

    let hasPlaceholder: Bool
    let hasErrorView: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(appearance: $appearance,
                    onLoad: onLoad,
                    onEmpty: onEmpty,
                    onFail: onFail)
    }

    func makeUIView(context: Context) -> MindboxEmbeddedBlockView {
        let blockView = MindboxEmbeddedBlockView(placeSystemName: placeSystemName,
                                                 height: height,
                                                 loadingStrategy: loadingStrategy,
                                                 timeout: timeout,
                                                 animatesReveal: animatesReveal)
        let coordinator = context.coordinator
        blockView.delegate = coordinator
        Self.observe(blockView, with: coordinator)
        syncStandIns(in: blockView)
        return blockView
    }

    /// Passes each look on with `isRevealAnimated`, read while the observer runs.
    static func observe(_ blockView: MindboxEmbeddedBlockView, with coordinator: Coordinator) {
        // The container holds the observer, so it is captured weakly.
        blockView.setAppearanceObserver { [weak blockView] appearance in
            coordinator.update(appearance, animated: blockView?.isRevealAnimated ?? false)
        }
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

        var appearance: Binding<MindboxEmbeddedBlockAppearance?>
        var onLoad: (() -> Void)?
        var onEmpty: (() -> Void)?
        var onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

        private var isDetached = false

        /// `DispatchQueue.main` outside tests.
        private let schedule: (@escaping () -> Void) -> Void

        /// `withAnimation` with the SDK's reveal outside tests.
        private let animate: (@escaping () -> Void) -> Void

        init(appearance: Binding<MindboxEmbeddedBlockAppearance?>,
             onLoad: (() -> Void)?,
             onEmpty: (() -> Void)?,
             onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?,
             schedule: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async { work() } },
             animate: @escaping (@escaping () -> Void) -> Void = { changes in
                 withAnimation(.easeInOut(duration: MindboxEmbeddedBlockView.revealAnimationDuration)) { changes() }
             }) {
            self.appearance = appearance
            self.onLoad = onLoad
            self.onEmpty = onEmpty
            self.onFail = onFail
            self.schedule = schedule
            self.animate = animate
        }

        /// Writes the look, under the reveal animation when the view says `animated`.
        func update(_ newAppearance: MindboxEmbeddedBlockAppearance, animated: Bool) {
            schedule { [weak self] in
                guard let self, !self.isDetached,
                      self.appearance.wrappedValue != newAppearance else { return }

                let write = { self.appearance.wrappedValue = newAppearance }

                if animated {
                    self.animate(write)
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
