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
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The system name of the place from the admin panel, given at creation. Decides what content
    /// the SDK puts inside.
    public let placeSystemName: String

    /// Receives the block events. Assigning a delegate after the content already resolved still
    /// delivers that outcome, so subscribing late cannot lose it.
    public weak var delegate: MindboxEmbeddedBlockViewDelegate? {
        didSet {
            // The same delegate is not a new subscriber: the host rebuilds its layout on the
            // outcome, and the rebuild reassigns the delegate again — answering that would loop.
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

    /// What the container shows, for the SwiftUI wrapper — see `EmbeddedBlockPresentation`.
    var onPresentationChange: ((EmbeddedBlockPresentation) -> Void)?

    // MARK: - State

    private let contentProvider: EmbeddedBlockWebViewProvider

    private let preferredHeight: CGFloat

    private let waitBudget: EmbeddedBlockWaitBudget

    private lazy var layers = EmbeddedBlockLayerHost(container: self)

    private lazy var defaultPlaceholder = EmbeddedBlockShimmerView()

    private var state: EmbeddedBlockState = .loading {
        didSet {
            updateTimeout(from: oldValue)
            apply(state)
        }
    }

    /// Space once ceded to the host is not taken back: a retry does not reopen the container for
    /// its placeholder — only shown content expands it back, or an explicit reload.
    private var hasCollapsed = false

    private var shownLayer: EmbeddedBlockPresentation.Layer = .placeholder

    private enum BlockEvent {
        case loaded
        case failed
    }

    private var deliveredEvent: BlockEvent?

    private var isDeliveryScheduled = false

    // MARK: - Life cycle

    /// - Parameters:
    ///   - placeSystemName: The place system name from the admin panel.
    ///   - height: The height the block occupies while loading and shown. Reserving it is the
    ///     host's job and there is no default: a height of 0 or less leaves the block invisible
    ///     whatever its content turns out to be, so the SDK reports it as an integration error.
    ///   - timeout: How long the block waits to learn what it shows — the config has to
    ///     arrive and the selection has to run — before collapsing as empty, in seconds. `nil`
    ///     means the SDK default of 30. An answer that arrives after that no longer expands the
    ///     block; the next attempt starts when the block enters the window again. The separate
    ///     budget a loaded page gets to render itself is not affected.
    public convenience init(placeSystemName: String, height: CGFloat, timeout: TimeInterval? = nil) {
        self.init(placeSystemName: placeSystemName,
                  height: height,
                  contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(placeSystemName: placeSystemName),
                  timeout: timeout)
    }

    /// Blocks are not created from storyboards: the place system name and the height are required
    /// and have no sensible defaults.
    @available(*, unavailable, message: "Use init(placeSystemName:height:) instead")
    public required init?(coder: NSCoder) {
        return nil
    }

    init(placeSystemName: String,
         height: CGFloat,
         contentProvider: EmbeddedBlockWebViewProvider,
         timeout: TimeInterval? = nil,
         waitBudget: EmbeddedBlockWaitBudget? = nil) {
        self.placeSystemName = placeSystemName
        self.preferredHeight = height
        self.contentProvider = contentProvider
        let answerTimeout = Self.sanitizedTimeout(timeout, placeSystemName: placeSystemName)
        self.waitBudget = waitBudget ?? EmbeddedBlockWaitBudget(
            placeSystemName: placeSystemName,
            duration: { [weak contentProvider] in
                contentProvider?.isAwaitingAnswer == false
                    ? TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
                    : answerTimeout
            }
        )
        super.init(frame: .zero)
        warnIfHeightReservesNothing()
        setUpContainer()
    }

    /// A non-positive timeout would collapse every block before the config had a chance, so it is
    /// reported and replaced with the default rather than obeyed.
    static func sanitizedTimeout(_ timeout: TimeInterval?, placeSystemName: String) -> TimeInterval {
        guard let timeout else {
            return TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)
        }

        guard timeout > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given timeout \(timeout): it must be positive, using the default \(Constants.EmbeddedBlock.answerTimeoutSeconds) s",
                          level: .error, category: .embeddedBlocks)
            return TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)
        }

        return timeout
    }

    /// Zero height is not a collapse: the block runs its whole cycle, it is simply never visible.
    private func warnIfHeightReservesNothing() {
        guard preferredHeight <= 0 else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was created with height \(preferredHeight): it reserves no space and stays invisible whatever loads. Pass the height it should occupy.",
                      level: .error,
                      category: .embeddedBlocks)
    }

    deinit {
        waitBudget.pause()
        contentProvider.stop()
    }

    private func setUpContainer() {
        clipsToBounds = true
        backgroundColor = .clear

        contentProvider.onStateChange = { [weak self] state in
            self?.state = state
        }

        // The wait changes its nature once content arrives: the budget starts over with the page's
        // own — shorter — patience.
        contentProvider.onContentArrived = { [weak self] in
            guard let self else { return }

            self.waitBudget.reset()
            self.waitBudget.armIfNeeded()
        }

        waitBudget.isNeeded = { [weak self] in
            guard let self else { return false }
            return self.window != nil && self.state == .loading
        }
        waitBudget.onExpire = { [weak self] in
            self?.handleTimeout()
        }

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

    override public func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' left the window, stopping content", category: .embeddedBlocks)
            // A pause, not a reset: leaving the window does not cancel an attempt already started.
            waitBudget.pause()
            contentProvider.stop()
        } else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' entered the window, starting content", category: .embeddedBlocks)
            contentProvider.start()
            waitBudget.armIfNeeded()
        }
    }

    /// Internal and without a public wrapper: automatic reloads — on failure, on returning to the
    /// app — will be built on this method.
    func reload() {
        guard window != nil else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload skipped: the block is not in a window",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload requested", category: .embeddedBlocks)
        waitBudget.reset()
        // A new attempt means a new outcome: the host must hear it even if it matches the previous one.
        deliveredEvent = nil
        // A reload is the host's explicit consent to the full cycle with the placeholder.
        hasCollapsed = false
        contentProvider.reload()
        waitBudget.armIfNeeded()
    }

    /// Running out of patience is a failure only for a page that was built and stayed silent; a
    /// block that never learned what to show has nothing to show — an outcome, not a breakage.
    private func handleTimeout() {
        let hadContentToLoad = !contentProvider.isAwaitingAnswer

        contentProvider.reportPageTimedOut()
        // The provider must not resurrect content the container has already given up on.
        contentProvider.stop()
        state = hadContentToLoad ? .failed : .empty
    }

    // MARK: - Layers

    /// The budget lives per attempt: an ongoing load counts down its remainder, anything else
    /// resets the count. Arming again is up to whoever knows the block is awaited.
    private func updateTimeout(from previous: EmbeddedBlockState) {
        guard state != .loading || previous != .loading else { return }

        waitBudget.reset()
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
        case .loading: return hasCollapsed ? .nothing : .placeholder
        case .ready: return .content
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

    private func refreshPlaceholder() {
        guard shownLayer == .placeholder else { return }
        layers.show(view(for: .placeholder))
    }

    private func refreshErrorView() {
        guard state == .failed, shownLayer == .errorView else { return }
        apply(state)
    }

    // MARK: - Host events

    /// Next main-queue turn: the state can flip mid-layout-pass, and re-entering host code from
    /// there breaks the host's layout.
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
