//
//  MindboxEmbeddedBlockView.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// A drop-in container for a Mindbox embedded block.
///
/// Created with the `placeSystemName` of the place from the admin panel and the `height` the block
/// should occupy.
/// Put it anywhere in the app and constrain its position and width only — the height is applied
/// by the container itself through `intrinsicContentSize`: the one given at creation while the
/// content is loading and shown, and 0 when there is nothing to show (a failure or an empty
/// block), so the block takes no space and is invisible in the host layout. Both outcomes can be
/// customized: `placeholderView` replaces the stock loading shimmer, and `errorView` opts into
/// showing a failure instead of collapsing.
///
/// What exactly lives inside is decided by the SDK from the `placeSystemName`, not by the host. The
/// block flow belongs to the SDK too: the container starts its content when it enters a window
/// and stops it when it leaves. The host app observes the outcome through `delegate` and nothing
/// else.
///
/// The container itself is a machine of four content states and one visible layer for each of
/// them. Everything that could be moved out of it wholesale has been: showing the layers went to
/// `EmbeddedBlockLayerHost`, the waiting budget together with its background pause to
/// `EmbeddedBlockReadyTimeout`.
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The system name of the place from the admin panel, given at creation. Decides what content
    /// the SDK puts inside.
    public let placeSystemName: String

    /// Receives the block events. Assigning a delegate after the content already resolved still
    /// delivers that outcome, so subscribing late cannot lose it.
    public weak var delegate: MindboxEmbeddedBlockViewDelegate? {
        didSet {
            // The same delegate is not a new subscriber. The host routinely reassigns it on every
            // reused cell, and answering that with an already heard outcome is not allowed: the
            // host rebuilds its layout on the outcome, and the rebuild reassigns the delegate again.
            guard delegate !== oldValue else { return }

            deliveredEvent = nil
            scheduleDelivery()
        }
    }

    /// The view shown in place of the content while it is loading. `nil` — the default — means
    /// the SDK's own shimmer. The placeholder fills the whole container, so it is laid out to the
    /// container's width and the height given at creation. Can be swapped at any moment, including
    /// mid-loading.
    public var placeholderView: UIView? {
        didSet {
            guard placeholderView !== oldValue else { return }
            refreshPlaceholder()
        }
    }

    /// The view shown when the block fails. `nil` — the default — keeps the failure invisible:
    /// the container collapses to zero height. Setting a view opts into showing the failure
    /// instead: the container keeps the height given at creation and fills itself with this view.
    /// The SDK ships no stock error screen — what a failed block looks like is the host's design
    /// decision. Applies only to failures; an empty block always collapses.
    ///
    /// A view assigned mid-failure swaps the error screen that is already shown, but never
    /// expands a block that has already collapsed — reopening space the host layout has
    /// reclaimed would make the layout jump. Such a view is remembered and takes effect on
    /// the next load.
    public var errorView: UIView? {
        didSet {
            guard errorView !== oldValue else { return }
            refreshErrorView()
        }
    }

    /// What the container shows, for the SwiftUI wrapper: it sizes the representable itself instead
    /// of relying on `intrinsicContentSize`, and it draws the host's placeholder and error screen
    /// itself instead of handing them over as `UIView`s. Internal: not part of the public API.
    var onPresentationChange: ((EmbeddedBlockPresentation) -> Void)?

    // MARK: - State

    private let contentProvider: EmbeddedBlockWebViewProvider

    /// The height the host reserved for the block at creation. The container holds it while the
    /// content is loading and shown, and drops to 0 when there is nothing to show.
    private let preferredHeight: CGFloat

    private let timeout: EmbeddedBlockReadyTimeout

    private lazy var layers = EmbeddedBlockLayerHost(container: self)

    private lazy var defaultPlaceholder = EmbeddedBlockShimmerView()

    private var state: EmbeddedBlockState = .loading {
        didSet {
            updateTimeout(from: oldValue)
            apply(state)
        }
    }

    /// Whether the block has collapsed since the last explicit reload.
    ///
    /// Space once ceded to the host is not taken back: a retry — and the block gets one on every
    /// return to a window — does not expand the container back for the placeholder. Otherwise a
    /// block that failed to show would jerk the host layout by its height and flash the shimmer
    /// on every pass across the screen, showing nothing in the end. Only shown content expands it
    /// back — or an explicit reload, which is precisely consent to the full cycle anew.
    private var hasCollapsed = false

    /// The layer shown right now. Stored, not computed on the fly: it is the one source for both
    /// the height and the report to the wrapper — otherwise they could diverge. It also tells a
    /// shown error screen from one merely assigned: an `errorView` given after collapse is not shown.
    private var shownLayer: EmbeddedBlockPresentation.Layer = .placeholder

    /// There are two public outcomes: shown or not shown. To the host "empty" is the same non-show
    /// as a failure; the difference lives only in the container (an empty block shows no `errorView`).
    private enum BlockEvent {
        case loaded
        case failed
    }

    /// The last event handed to the current delegate — keeps the same outcome from being reported
    /// twice, for instance when restarted content fails again.
    private var deliveredEvent: BlockEvent?

    private var isDeliveryScheduled = false

    // MARK: - Life cycle

    /// - Parameters:
    ///   - placeSystemName: The system name of the place from the admin panel.
    ///   - height: The height the block occupies while loading and shown. Reserving it is the
    ///     host's job and there is no default: a height of 0 or less leaves the block invisible
    ///     whatever its content turns out to be, so the SDK reports it as an integration error.
    public convenience init(placeSystemName: String, height: CGFloat) {
        self.init(placeSystemName: placeSystemName,
                  height: height,
                  contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(id: placeSystemName))
    }

    /// Blocks are not created from storyboards: the place system name and the height are required
    /// and have no sensible defaults. Create the view in code with `init(placeSystemName:height:)`.
    @available(*, unavailable, message: "Use init(placeSystemName:height:) instead")
    public required init?(coder: NSCoder) {
        return nil
    }

    /// - Parameter timeout: The waiting budget as a whole, not just its duration: the clock, the
    ///   scheduler, and the background subscription all live inside it, and swapping them one by
    ///   one through the container would mean threading three parameters through it just for tests.
    init(placeSystemName: String,
         height: CGFloat,
         contentProvider: EmbeddedBlockWebViewProvider,
         timeout: EmbeddedBlockReadyTimeout? = nil) {
        self.placeSystemName = placeSystemName
        self.preferredHeight = height
        self.contentProvider = contentProvider
        self.timeout = timeout ?? EmbeddedBlockReadyTimeout(
            blockId: placeSystemName,
            duration: TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
        )
        super.init(frame: .zero)
        warnIfHeightReservesNothing()
        setUpContainer()
    }

    /// The host sets the block height, and zero means not "the block collapsed" but "no space was
    /// reserved for it": the block runs its whole cycle, hands the host its events and stays
    /// invisible. There are no symptoms at all — the block is simply not visible — and the cause is
    /// the most common one possible, so the SDK says it out loud.
    private func warnIfHeightReservesNothing() {
        guard preferredHeight <= 0 else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was created with height \(preferredHeight): it reserves no space and stays invisible even when its content loads. "
                      + "Pass the height the block should occupy.",
                      level: .error,
                      category: .embeddedBlocks)
    }

    deinit {
        timeout.pause()
        contentProvider.stop()
    }

    private func setUpContainer() {
        clipsToBounds = true
        backgroundColor = .clear

        contentProvider.onStateChange = { [weak self] state in
            self?.state = state
        }

        timeout.isNeeded = { [weak self] in
            guard let self else { return false }
            return self.window != nil && self.state == .loading
        }
        timeout.onExpire = { [weak self] in
            self?.handleTimeout()
        }

        // The block reserves its space right away, before any loading starts, and reserved space
        // must not look blank.
        layers.show(view(for: shownLayer))
    }

    // MARK: - Layout

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    /// Hosts that lay out by frames rather than by constraints get the same height here.
    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: contentHeight)
    }

    private var contentHeight: CGFloat {
        switch shownLayer {
        case .placeholder, .content, .errorView: return max(0, preferredHeight)
        case .nothing: return 0
        }
    }

    // MARK: - Visibility

    /// Visibility drives the content: there is no reason to hold content for a container that is
    /// not in a window, and no public way for the host to start or stop it by hand.
    override public func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' left the window, stopping content", category: .embeddedBlocks)
            // A pause, not a reset: nobody waits for a block outside a window, but that does not
            // cancel an attempt already started — once back, it counts down its remainder.
            timeout.pause()
            contentProvider.stop()
        } else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' entered the window, starting content", category: .embeddedBlocks)
            contentProvider.start()
            timeout.armIfNeeded()
        }
    }

    /// Reloads the block: the content starts loading from scratch, the address is requested anew
    /// bypassing the cache, the block returns to loading with its placeholder and a fresh timeout.
    ///
    /// Internal and without a public wrapper: automatic reloads — on failure, on returning to the
    /// app — will be built on this method, and there is no reason yet for the host to decide when
    /// to refresh the block.
    func reload() {
        guard window != nil else {
            // Content lives only while the block is in a window; reloading an invisible block is
            // pointless — it loads anew by itself once it returns to a window.
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload skipped: the block is not in a window",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload requested", category: .embeddedBlocks)
        timeout.reset()
        // A new attempt means a new outcome: the host must hear it in full, even if it matches
        // the previous one.
        deliveredEvent = nil
        // And a new attempt is entitled to take space again: a reload is the host's explicit consent
        // to the full cycle with the placeholder, unlike the block's silent return to a window.
        hasCollapsed = false
        contentProvider.reload()
        timeout.armIfNeeded()
    }

    private func handleTimeout() {
        // Stop first: the provider must not resurrect content the container already gave up on.
        contentProvider.stop()
        state = .failed
    }

    // MARK: - Layers

    /// The waiting budget lives per attempt, not per state: an ongoing load counts down its
    /// remainder, while everything else — a known outcome or a load started anew — resets the count.
    /// Arming it again is up to whoever knows whether the block is awaited: entering a window and
    /// returning from the background.
    private func updateTimeout(from previous: EmbeddedBlockState) {
        guard state != .loading || previous != .loading else { return }

        timeout.reset()
    }

    private func apply(_ state: EmbeddedBlockState) {
        shownLayer = layer(for: state)

        if shownLayer == .nothing {
            hasCollapsed = true
        }

        layers.show(view(for: shownLayer))

        invalidateIntrinsicContentSize()
        onPresentationChange?(EmbeddedBlockPresentation(layer: shownLayer, height: contentHeight))
        scheduleDelivery()
    }

    private func layer(for state: EmbeddedBlockState) -> EmbeddedBlockPresentation.Layer {
        switch state {
        // A collapsed block stays collapsed even while it loads anew: a retry does not win back
        // the space the host has already reclaimed.
        case .loading: return hasCollapsed ? .nothing : .placeholder
        case .ready: return .content
        // A failure is shown only to those who opted in explicitly; for the rest the block collapses.
        case .failed: return errorView == nil ? .nothing : .errorView
        case .empty: return .nothing
        }
    }

    private func view(for layer: EmbeddedBlockPresentation.Layer) -> UIView? {
        switch layer {
        case .placeholder: return placeholderView ?? defaultPlaceholder
        case .content: return contentProvider.contentView
        case .errorView: return errorView
        case .nothing: return nil
        }
    }

    /// A placeholder swap takes effect immediately, but only while the placeholder is what the
    /// container shows — in any other state the new view is simply remembered for the next load.
    private func refreshPlaceholder() {
        guard shownLayer == .placeholder else { return }
        layers.show(view(for: .placeholder))
    }

    /// Swapping a shown error screen takes effect immediately, but a collapsed block is not
    /// reopened retroactively: the host layout already reclaimed the space, and expanding it out
    /// of nowhere would make the layout jump. The new view is remembered for the next load. In
    /// any other state the view is simply remembered too.
    private func refreshErrorView() {
        guard state == .failed, shownLayer == .errorView else { return }
        apply(state)
    }

    // MARK: - Host events

    /// Events are handed over on the next main-queue turn: the state can flip in the middle of a
    /// layout pass, and re-entering host code from there is a good way to break the host's layout.
    private func scheduleDelivery() {
        guard !isDeliveryScheduled else { return }

        isDeliveryScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.deliverPendingEvent()
        }
    }

    private func deliverPendingEvent() {
        isDeliveryScheduled = false

        guard let delegate = delegate,
              let event = event(for: state),
              event != deliveredEvent else {
            return
        }

        deliveredEvent = event

        switch event {
            case .loaded: delegate.mindboxEmbeddedBlockViewDidLoad(self)
            case .failed: delegate.mindboxEmbeddedBlockViewDidFail(self)
        }
    }

    private func event(for state: EmbeddedBlockState) -> BlockEvent? {
        switch state {
            case .loading: return nil
            case .ready: return .loaded
            case .failed, .empty: return .failed
        }
    }
}
