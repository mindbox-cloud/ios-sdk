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
            // Nor is a released block's own teardown one: it drops the delegate on its way out.
            guard delegate !== oldValue, !isReleased else { return }

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
    /// A view assigned mid-failure swaps the error screen that is already shown, and `nil` given
    /// while one is shown takes the failure back down to a collapse — the space returns to the host
    /// layout. What neither does is expand a block that has already collapsed: reopening space the
    /// host layout has reclaimed would make the layout jump, so such a view is remembered for a load
    /// that starts the cycle anew, never for the silent retry a return to the screen brings.
    public var errorView: UIView? {
        didSet {
            guard errorView !== oldValue else { return }
            refreshErrorView()
        }
    }

    // MARK: - Wrapper API

    /// Reports how the block occupies its place, for wrappers that lay it out themselves instead of
    /// relying on `intrinsicContentSize` — see `MindboxEmbeddedBlockAppearance`.
    ///
    /// The current value arrives right away on subscribing: a wrapper that comes after the outcome
    /// cannot miss what the block already decided.
    @_spi(Internal)
    public func setAppearanceObserver(_ observer: ((MindboxEmbeddedBlockAppearance) -> Void)?) {
        appearanceObserver = observer
        observer?(shownAppearance)
    }

    /// Tells the block whether the host still shows it — a second source for the same input as
    /// window visibility: the content runs while `window != nil && isHostVisible`.
    ///
    /// For wrappers whose whole app lives in one window. In Flutter every screen shares it, so
    /// leaving a screen never takes the block out of a window: the block would keep waiting — and
    /// spending its budget — on a screen nobody is looking at, and could collapse before the user
    /// ever got there. `true` by default, so a wrapper that says nothing behaves as before.
    ///
    /// The semantics are exactly those of leaving and entering a window: a pause, not a reset. A
    /// block hidden mid-load keeps the page it has and the remainder of its budget; shown again, it
    /// counts that remainder down instead of starting the budget anew.
    @_spi(Internal)
    public func setHostVisible(_ isHostVisible: Bool) {
        guard self.isHostVisible != isHostVisible else { return }

        self.isHostVisible = isHostVisible
        updateContentActivity(reason: isHostVisible ? "was shown by the host wrapper"
                                                   : "was hidden by the host wrapper")
    }

    /// Stops the block for good: the content stops, the wrapper's callbacks are dropped, and the
    /// block does not start again even while it stays in a window.
    ///
    /// The container stops the same things in `deinit`, so a wrapper that simply lets the view go is
    /// already correct. This is for wrappers that cannot promise that: a platform-view factory holds
    /// the view for as long as the platform sees fit, and the block should stop when the screen is
    /// gone rather than when the last reference is. What the container holds — the page among it —
    /// still goes away with the container itself, so a released block is meant to be let go right
    /// after, not kept around.
    @_spi(Internal)
    public func release() {
        guard !isReleased else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was released by the host wrapper",
                      category: .embeddedBlocks)
        isReleased = true
        delegate = nil
        appearanceObserver = nil
        updateContentActivity(reason: "was released by the host wrapper")
        // Stopping is only a pause now, and a released block is not coming back: the page is closed
        // here rather than waiting for the container's own deallocation.
        contentProvider.teardown()
    }

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

    /// Whether the block has already settled on a place without content — collapsed, or showing the
    /// host's error view.
    ///
    /// A settled block keeps what it shows. A retry — and the block gets one on every return to a
    /// window — is not a reload: the page behind the place is the one that already failed, so it
    /// answers the same way, while the host watches its layout jerk by the block's height and a
    /// placeholder flash on every pass across the screen, to show nothing in the end. That holds for
    /// the error view just as much as for a collapse: a screen replaced by a placeholder and then by
    /// itself again is the same flicker.
    ///
    /// Two things end it: content that actually appeared, and an explicit reload — which is precisely
    /// consent to the full cycle anew.
    private var hasSettled = false

    /// What the container shows right now. Stored, not computed on the fly: it is the one source for
    /// both the height and the report to the wrapper — otherwise they could diverge. It also tells a
    /// shown error screen from one merely assigned: an `errorView` given after collapse is not shown.
    private var shownAppearance: MindboxEmbeddedBlockAppearance = .placeholder

    private var appearanceObserver: ((MindboxEmbeddedBlockAppearance) -> Void)?

    /// Whether the wrapper's host still shows the block. Nobody says otherwise until a wrapper does.
    private var isHostVisible = true

    /// Whether a wrapper has released the block: then it stays stopped whatever the window says.
    private var isReleased = false

    /// Whether the content is running right now. Three sources drive one decision — the window, the
    /// wrapper's host, a release — and each of them can repeat what another has already said, so the
    /// switch needs to know its own position.
    private var isContentRunning = false

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
        contentProvider.teardown()
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
            return self.isEffectivelyVisible && self.state == .loading
        }
        waitBudget.onExpire = { [weak self] in
            self?.handleTimeout()
        }

        // The block reserves its space right away, before any loading starts, and reserved space
        // must not look blank.
        layers.show(view(for: shownAppearance))
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
        shownAppearance == .collapsed ? 0 : max(0, preferredHeight)
    }

    // MARK: - Visibility

    /// Whether anybody is looking at the block. The window answers that for a UIKit host; a wrapper
    /// whose app has a single window answers the rest through `setHostVisible(_:)`, and a released
    /// block is not looked at by definition.
    private var isEffectivelyVisible: Bool {
        window != nil && isHostVisible && !isReleased
    }

    /// Visibility drives the content: there is no reason to hold content for a block nobody is
    /// looking at, and no public way for the host to start or stop it by hand.
    override public func didMoveToWindow() {
        super.didMoveToWindow()

        updateContentActivity(reason: window == nil ? "left the window" : "entered the window")
    }

    /// - Parameter reason: What changed, for the log. The three sources of visibility lead here, and
    ///   a log line saying only "stopped" leaves the interesting half out.
    private func updateContentActivity(reason: String) {
        let shouldRun = isEffectivelyVisible

        guard shouldRun != isContentRunning else { return }

        isContentRunning = shouldRun

        if shouldRun {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' \(reason), starting content",
                          category: .embeddedBlocks)
            contentProvider.start()
            waitBudget.armIfNeeded()
        } else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' \(reason), stopping content",
                          category: .embeddedBlocks)
            // A pause, not a reset: nobody waits for a block that is not on screen, but that does
            // not cancel an attempt already started — once back, it counts down its remainder.
            waitBudget.pause()
            contentProvider.stop()
        }
    }

    /// Internal and without a public wrapper: automatic reloads — on failure, on returning to the
    /// app — will be built on this method.
    func reload() {
        guard isEffectivelyVisible else {
            // Content lives only while somebody is looking at the block; reloading an invisible
            // block is pointless — it loads anew by itself once it is back on screen.
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload skipped: the block is not on screen",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload requested", category: .embeddedBlocks)
        waitBudget.reset()
        // A new attempt means a new outcome: the host must hear it even if it matches the previous one.
        deliveredEvent = nil
        // And a new attempt is entitled to the full cycle again: a reload is the host's explicit
        // consent to it, placeholder included, unlike the block's silent return to a window.
        hasSettled = false
        contentProvider.reload()
        waitBudget.armIfNeeded()
    }

    /// Running out of patience is a failure only for a page that was built and stayed silent; a
    /// block that never learned what to show has nothing to show — an outcome, not a breakage.
    private func handleTimeout() {
        let hadContentToLoad = !contentProvider.isAwaitingAnswer

        contentProvider.reportPageTimedOut()
        // The provider must not resurrect content the container has already given up on — and a stop
        // no longer guarantees that, since a paused attempt is meant to resume.
        contentProvider.abandonAttempt()
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
        shownAppearance = appearance(for: state)

        switch shownAppearance {
        // A place without content, however it is drawn, is what the block settles on.
        case .collapsed, .error: hasSettled = true
        // And content that actually appeared ends it: from here the block is an ordinary one again,
        // and the next load it really starts is entitled to its placeholder.
        case .content: hasSettled = false
        case .placeholder: break
        }

        layers.show(view(for: shownAppearance))

        invalidateIntrinsicContentSize()
        appearanceObserver?(shownAppearance)
        scheduleDelivery()
    }

    private func appearance(for state: EmbeddedBlockState) -> MindboxEmbeddedBlockAppearance {
        switch state {
        case .loading:
            guard hasSettled else { return .placeholder }

            // A block that already settled keeps what it shows even while it loads anew: a retry
            // earns neither the space the host has reclaimed nor a placeholder over the error screen.
            // What it does not keep is an error screen the host has taken away in the meantime —
            // there is nothing left to draw, so the block collapses.
            return shownAppearance == .error && errorView == nil ? .collapsed : shownAppearance
        case .ready: return .content
        case .failed:
            // A failure is shown only to those who opted in explicitly; for the rest the block collapses.
            guard hasSettled else { return errorView == nil ? .collapsed : .error }

            // A settled block keeps what it shows when the retry fails too: an error view assigned
            // after the collapse must not reopen space the host layout has reclaimed. The exception
            // is the loading branch's one — an error screen the host has taken away leaves nothing
            // to draw, so the block collapses.
            return shownAppearance == .error && errorView == nil ? .collapsed : shownAppearance
        case .empty: return .collapsed
        }
    }

    private func view(for appearance: MindboxEmbeddedBlockAppearance) -> UIView? {
        switch appearance {
        case .placeholder: return placeholderView ?? defaultPlaceholder
        case .content: return contentProvider.contentView
        case .error: return errorView
        case .collapsed: return nil
        }
    }

    private func refreshPlaceholder() {
        guard shownAppearance == .placeholder else { return }
        layers.show(view(for: .placeholder))
    }

    /// Not only a live failure: a block that settled on its error screen goes on showing it while the
    /// next attempt loads, and a host swapping or taking that view away has to be obeyed there too.
    /// What is shown is the subject — a block that has already collapsed is never expanded by a view
    /// assigned afterwards.
    private func refreshErrorView() {
        guard shownAppearance == .error else { return }

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
