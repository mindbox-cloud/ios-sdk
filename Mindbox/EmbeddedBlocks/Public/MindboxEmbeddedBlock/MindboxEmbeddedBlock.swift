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

/// A SwiftUI view that shows a Mindbox embedded block, the SwiftUI counterpart of
/// ``MindboxEmbeddedBlockView``.
///
/// Give it the place's system name from the admin panel and the height the block occupies; the layout
/// decides only its position and width. While its content loads, the block either reserves
/// its height with a placeholder or stays at zero height, as ``MindboxEmbeddedBlock/loadingStrategy``
/// says, and the first frame already has that height. When there is nothing to show, or the block fails
/// without an error view, it collapses to zero height.
///
/// A `placeSystemName` naming another place replaces the block with a new one; a new `height` resizes it
/// without reloading. `loadingStrategy`, `timeout` and `animatesReveal` are read only when the block is
/// created.
///
/// ``MindboxEmbeddedBlock/placeholder(_:)`` replaces the SDK's loading shimmer, and
/// ``MindboxEmbeddedBlock/errorView(_:)`` shows a failure instead of collapsing. Both are drawn as ordinary
/// SwiftUI views and get the surrounding environment. They are methods of `MindboxEmbeddedBlock`, so apply
/// them before any SwiftUI modifier such as `.frame(…)` or `.padding(…)`.
///
/// `onLoad`, `onEmpty` and `onFail` arrive like the matching ``MindboxEmbeddedBlockViewDelegate`` calls.
///
/// ```swift
/// MindboxEmbeddedBlock(placeSystemName: "stories", height: 104,
///                      loadingStrategy: .automatic,
///                      onEmpty: hideSection,
///                      onFail: { reason in log("stories failed: \(reason)") })
/// ```
///
/// A collapsed block is zero points tall, but a stack still adds its spacing around it. To give the space
/// back completely, remove the section from the layout in `onEmpty`, and in `onFail` unless the block
/// shows its error view; ``MindboxEmbeddedBlock/errorView(_:)`` says when it does.
@available(iOS 13.0, *)
public struct MindboxEmbeddedBlock: View {

    private let placeSystemName: String
    private let height: CGFloat
    private let timeout: TimeInterval?

    /// What the block shows while its content loads.
    public let loadingStrategy: MindboxEmbeddedBlockLoadingStrategy

    /// Whether the SDK animates the appearance of the content. The system's Reduce Motion setting also
    /// turns the animation off.
    public let animatesReveal: Bool

    private let onLoad: (() -> Void)?
    private let onEmpty: (() -> Void)?
    private let onFail: ((MindboxEmbeddedBlockFailReason) -> Void)?

    private(set) var placeholderBuilder: (() -> AnyView)?
    private(set) var errorBuilder: (() -> AnyView)?

    /// Creates a block for a place.
    ///
    /// - Parameters:
    ///   - placeSystemName: The place's system name from the admin panel. Surrounding whitespace and
    ///     letter case are ignored: `Main-Screen-Top` and `main-screen-top` are the same place.
    ///   - height: The height, in points, the block occupies while it shows content, a placeholder or
    ///     an error view. A new value resizes the block without reloading its content. 0 or less keeps
    ///     the block invisible and, at creation, is logged as an error.
    ///   - loadingStrategy: What the block shows while its content loads; see
    ///     ``MindboxEmbeddedBlockLoadingStrategy``.
    ///   - timeout: How long, in seconds, the block waits for the SDK to choose its content before it
    ///     fails with ``MindboxEmbeddedBlockFailReason/networkError``. Only time in a window with the
    ///     app in the foreground counts. `nil` means 30; 0 or less is logged as an error and means 30
    ///     too.
    ///   - animatesReveal: Whether the SDK animates the appearance of the content: a fade, and the growth
    ///     of a block that waited hidden. The system's Reduce Motion setting also turns it off. Turn it
    ///     off to animate the block's container yourself in `onLoad`.
    ///   - onLoad: Called when the content is shown. A block that waited hidden takes its `height` at
    ///     this point.
    ///   - onEmpty: Called when the place has nothing to show. The block collapses; the error view does
    ///     not apply.
    ///   - onFail: Called when the block could not be shown; it collapses or shows its error view. The
    ///     reason is for logs and analytics.
    public init(placeSystemName: String,
                height: CGFloat,
                loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic,
                timeout: TimeInterval? = nil,
                animatesReveal: Bool = true,
                onLoad: (() -> Void)? = nil,
                onEmpty: (() -> Void)? = nil,
                onFail: ((MindboxEmbeddedBlockFailReason) -> Void)? = nil) {
        self.placeSystemName = MindboxEmbeddedBlockView.normalizedPlaceSystemName(placeSystemName)
        self.height = height
        self.timeout = timeout
        self.loadingStrategy = loadingStrategy
        self.animatesReveal = animatesReveal
        self.onLoad = onLoad
        self.onEmpty = onEmpty
        self.onFail = onFail
    }

    /// Shows this view instead of the SDK's shimmer while the block is loading.
    ///
    /// Calling it again replaces the previous placeholder. A block that waits hidden while it loads
    /// shows no placeholder; see ``MindboxEmbeddedBlock/loadingStrategy``.
    public func placeholder<Content: View>(@ViewBuilder _ build: @escaping () -> Content) -> Self {
        var block = self
        block.placeholderBuilder = { AnyView(build()) }
        return block
    }

    /// Shows this view instead of collapsing when the block fails.
    ///
    /// Applies only to a failure while the block takes its height. A block that is collapsed when it
    /// fails stays collapsed; a place with nothing to show always collapses.
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

    @State private var appearance: MindboxEmbeddedBlockAppearance?

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

    static func observe(_ blockView: MindboxEmbeddedBlockView, with coordinator: Coordinator) {
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
        coordinator.detach()
        uiView.release()
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

        private let schedule: (@escaping () -> Void) -> Void

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

        func detach() {
            isDetached = true
        }

        func mindboxEmbeddedBlockViewDidLoad(_ blockView: MindboxEmbeddedBlockView) {
            forward(onLoad)
        }

        func mindboxEmbeddedBlockViewDidBecomeEmpty(_ blockView: MindboxEmbeddedBlockView) {
            forward(onEmpty)
        }

        func mindboxEmbeddedBlockViewDidFail(_ blockView: MindboxEmbeddedBlockView,
                                             reason: MindboxEmbeddedBlockFailReason) {
            forward(onFail.map { fail in { fail(reason) } })
        }

        private func forward(_ outcome: (() -> Void)?) {
            guard let outcome else { return }

            if isDetached {
                schedule(outcome)
            } else {
                outcome()
            }
        }
    }
}
#endif
