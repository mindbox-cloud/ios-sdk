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
/// block), so the block takes no space and is invisible in the host layout. What the block shows
/// before the SDK answers is decided by `loadingStrategy`: a placeholder, nothing, or — by default —
/// nothing until the place has shown content once on this device and a placeholder from then on.
/// Both looks can be customized: `placeholderView` replaces the stock loading shimmer, and
/// `errorView` opts into showing a failure instead of collapsing.
///
/// The content is revealed with the SDK's own animation — it fades in, and a block that started
/// hidden grows to its height — unless `animatesReveal` is off. A host that wants an animation of its
/// own turns that off, puts the block in a container of its own and animates the container in
/// `mindboxEmbeddedBlockViewDidLoad`.
///
/// What exactly lives inside is decided by the SDK from the `placeSystemName`, not by the host. The
/// block flow belongs to the SDK too: the container starts its content when it enters a window
/// and stops it when it leaves. The host app observes the outcome through `delegate` and nothing
/// else: the block is shown, the place is empty, or the block failed with a reason.
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The system name of the place from the admin panel, given at creation and stripped of the
    /// whitespace around it. Decides what content the SDK puts inside.
    public let placeSystemName: String

    /// What the block shows until the SDK answers, given at creation.
    /// See `MindboxEmbeddedBlockLoadingStrategy`.
    public let loadingStrategy: MindboxEmbeddedBlockLoadingStrategy

    /// Whether the SDK animates the reveal of the content, given at creation. `false` swaps the layers
    /// and applies the height at once — for a host that animates the block's container itself.
    public let animatesReveal: Bool

    /// Receives the block events. Assigning a delegate after the content already resolved still
    /// delivers that outcome, so subscribing late cannot lose it.
    public weak var delegate: MindboxEmbeddedBlockViewDelegate? {
        didSet {
            // The same delegate is not a new subscriber: the host rebuilds its layout on the
            // outcome, and the rebuild reassigns the delegate again — answering that would loop.
            guard delegate !== oldValue, !isReleased else { return }

            deliveredEvent = nil
            scheduleDelivery()
        }
    }

    /// The view shown in place of the content while it is loading. `nil` — the default — means
    /// the SDK's own shimmer. The placeholder fills the whole container, so it is laid out to the
    /// container's width and the height given at creation. Can be swapped at any moment, including
    /// mid-loading. A block that waits hidden — see `loadingStrategy` — shows no placeholder at all.
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
    /// that starts the cycle anew, never for the silent retry a return to the screen brings. For the
    /// same reason a block that waits hidden shows no error screen: it never took the space.
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
    /// cannot miss what the block already decided. A wrapper that lays the block out also animates
    /// its height itself: the container animates only the content's fade for it.
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
        contentProvider.teardown()
    }

    /// The look a block of this place starts with, for wrappers that size the block before the
    /// container exists: a hidden start must not be preceded by a frame of reserved space.
    @_spi(Internal)
    public static func initialAppearance(placeSystemName: String,
                                         loadingStrategy: MindboxEmbeddedBlockLoadingStrategy) -> MindboxEmbeddedBlockAppearance {
        let place = normalizedPlaceSystemName(placeSystemName)
        let memory = DI.injectOrFail(EmbeddedBlockPlaceRemembering.self)
        return initialAppearance(for: loadingStrategy, hasShownContentBefore: memory.hasShownContent(at: place))
    }

    // MARK: - State

    private let contentProvider: EmbeddedBlockWebViewProvider

    private let placeMemory: EmbeddedBlockPlaceRemembering

    private let revealAnimation: EmbeddedBlockRevealAnimation

    var preferredHeight: CGFloat {
        didSet {
            guard preferredHeight != oldValue else { return }

            invalidateIntrinsicContentSize()
        }
    }

    private let waitBudget: EmbeddedBlockWaitBudget

    private lazy var layers = EmbeddedBlockLayerHost(container: self, animation: revealAnimation)

    private lazy var defaultPlaceholder = EmbeddedBlockShimmerView()

    private var state: EmbeddedBlockState = .loading {
        didSet {
            updateTimeout(from: oldValue)
            apply(state)
        }
    }

    /// Space once ceded to the host is not taken back: a retry does not reopen the container for
    /// its placeholder — only shown content expands it back, or an explicit reload. A block that
    /// starts hidden has ceded its space from birth.
    private var hasSettled: Bool

    private var shownAppearance: MindboxEmbeddedBlockAppearance

    private var appearanceObserver: ((MindboxEmbeddedBlockAppearance) -> Void)?

    private var isHostVisible = true

    private var isReleased = false

    private var isContentRunning = false

    /// The kind of outcome the host has heard — the deduplication key. Deliberately without the
    /// failure reason: a silent retry that fails differently is still the same outcome.
    private enum BlockEvent {
        case loaded
        case empty
        case failed
    }

    private var deliveredEvent: BlockEvent?

    private var isDeliveryScheduled = false

    // MARK: - Life cycle

    /// - Parameters:
    ///   - placeSystemName: The place system name from the admin panel. Whitespace around it is
    ///     ignored; the name itself is matched as it is, case included.
    ///   - height: The height the block occupies while loading and shown. Reserving it is the
    ///     host's job and there is no default: a height of 0 or less leaves the block invisible
    ///     whatever its content turns out to be, so the SDK reports it as an integration error.
    ///   - timeout: How long the block waits to learn what it shows — the config has to
    ///     arrive and the selection has to run — before failing as `networkError`, in seconds;
    ///     `errorView` applies. `nil` means the SDK default of 30. An answer that arrives after
    ///     that no longer expands the block; the next attempt starts when the block enters the
    ///     window again. The separate budget a loaded page gets to render itself is not affected.
    ///   - loadingStrategy: What the block shows until the SDK answers. `automatic` — the default —
    ///     keeps the block hidden until the place has shown content once on this device and puts a
    ///     placeholder there from then on.
    ///   - animatesReveal: Whether the SDK animates the reveal of the content. `true` by default.
    public convenience init(placeSystemName: String,
                            height: CGFloat,
                            timeout: TimeInterval? = nil,
                            loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic,
                            animatesReveal: Bool = true) {
        let place = Self.normalizedPlaceSystemName(placeSystemName)
        self.init(placeSystemName: place,
                  height: height,
                  contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(placeSystemName: place),
                  placeMemory: DI.injectOrFail(EmbeddedBlockPlaceRemembering.self),
                  loadingStrategy: loadingStrategy,
                  timeout: timeout,
                  animatesReveal: animatesReveal)
    }

    /// Padding is not part of a name: a name pasted from the admin panel with a stray space still
    /// finds its place, in sync with Android.
    static func normalizedPlaceSystemName(_ given: String) -> String {
        given.trimmingCharacters(in: .whitespacesAndNewlines)
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
         placeMemory: EmbeddedBlockPlaceRemembering,
         loadingStrategy: MindboxEmbeddedBlockLoadingStrategy,
         timeout: TimeInterval? = nil,
         animatesReveal: Bool = true,
         revealAnimation: EmbeddedBlockRevealAnimation = EmbeddedBlockRevealAnimation(),
         makeWaitBudget: ((_ placeSystemName: String, _ duration: @escaping () -> TimeInterval) -> EmbeddedBlockWaitBudget)? = nil) {
        self.placeSystemName = placeSystemName
        self.preferredHeight = height
        self.contentProvider = contentProvider
        self.placeMemory = placeMemory
        self.loadingStrategy = loadingStrategy
        self.animatesReveal = animatesReveal
        self.revealAnimation = revealAnimation
        let answerTimeout = Self.sanitizedTimeout(timeout, placeSystemName: placeSystemName)
        let duration: () -> TimeInterval = { [weak contentProvider] in
            contentProvider?.isAwaitingAnswer == false
                ? TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
                : answerTimeout
        }
        self.waitBudget = makeWaitBudget?(placeSystemName, duration)
            ?? EmbeddedBlockWaitBudget(placeSystemName: placeSystemName, duration: duration)

        // Decided synchronously, before the first layout pass: a wrapper reads the same answer
        // through `initialAppearance(placeSystemName:loadingStrategy:)`.
        let initial = Self.initialAppearance(for: loadingStrategy,
                                             hasShownContentBefore: placeMemory.hasShownContent(at: placeSystemName))
        self.shownAppearance = initial
        self.hasSettled = initial == .collapsed
        super.init(frame: .zero)
        warnIfPlaceIsMissing()
        warnIfHeightReservesNothing()
        logInitialLook()
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

    /// The strategy plus the place's memory, and nothing else: `placeholder` and `hidden` do not
    /// look at the memory, `automatic` is decided by it.
    static func initialAppearance(for strategy: MindboxEmbeddedBlockLoadingStrategy,
                                  hasShownContentBefore: Bool) -> MindboxEmbeddedBlockAppearance {
        switch strategy {
        case .placeholder:
            return .placeholder
        case .hidden:
            return .collapsed
        case .automatic:
            return hasShownContentBefore ? .placeholder : .collapsed
        }
    }

    /// An empty name addresses no place, and the name is never normalized: whatever the host
    /// passed is what the config is asked for.
    private func warnIfPlaceIsMissing() {
        guard placeSystemName.isEmpty else { return }

        Logger.common(message: "[EmbeddedBlock] A block was created without a place system name: it has nothing to resolve and stays invisible.",
                      level: .error,
                      category: .embeddedBlocks)
    }

    /// Zero height is not a collapse: the block runs its whole cycle, it is simply never visible.
    private func warnIfHeightReservesNothing() {
        guard preferredHeight <= 0 else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was created with height \(preferredHeight): it reserves no space and stays invisible whatever loads. Pass the height it should occupy.",
                      level: .error,
                      category: .embeddedBlocks)
    }

    private func logInitialLook() {
        let look = shownAppearance == .collapsed ? "hidden, taking no space" : "a placeholder"
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' starts with \(look) (strategy \(loadingStrategy))",
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

        // Known content on its way is not silence: the budget stands down until the page starts loading.
        contentProvider.onContentDelayed = { [weak self] in
            self?.waitBudget.reset()
        }

        waitBudget.isNeeded = { [weak self] in
            guard let self else { return false }
            return self.isEffectivelyVisible && self.state == .loading && !self.contentProvider.isAwaitingDelayedContent
        }
        waitBudget.onExpire = { [weak self] in
            self?.handleTimeout()
        }

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

    private var isEffectivelyVisible: Bool {
        window != nil && isHostVisible && !isReleased
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()

        updateContentActivity(reason: window == nil ? "left the window" : "entered the window")
    }

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
            // A pause, not a reset: leaving the window does not cancel an attempt already started.
            waitBudget.pause()
            contentProvider.stop()
        }
    }

    /// Internal and without a public wrapper: automatic reloads — on failure, on returning to the
    /// app — will be built on this method.
    func reload() {
        guard isEffectivelyVisible else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload skipped: the block is not on screen",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload requested", category: .embeddedBlocks)
        waitBudget.reset()
        // A new attempt means a new outcome: the host must hear it even if it matches the previous one.
        deliveredEvent = nil
        // A reload starts the cycle over from the block's first look: the strategy decides again —
        // the place's memory as it is now included — whether the block waits in a placeholder or hidden.
        resetToInitialLook()
        contentProvider.reload()
        waitBudget.armIfNeeded()
    }

    private func resetToInitialLook() {
        let initial = Self.initialAppearance(for: loadingStrategy,
                                             hasShownContentBefore: placeMemory.hasShownContent(at: placeSystemName))
        shownAppearance = initial
        hasSettled = initial == .collapsed
    }

    /// Both a page that was built and stayed silent and a block the SDK never answered fail — with
    /// different reasons, decided by the provider next to the failure report. The state arrives
    /// through `onStateChange`, reason attached; the provider also abandons the attempt so it cannot
    /// resurrect content the container has given up on.
    private func handleTimeout() {
        if contentProvider.isAwaitingAnswer {
            contentProvider.failUnanswered(waited: waitBudget.consumed)
        } else {
            contentProvider.failSilentPage()
        }
    }

    // MARK: - Layers

    /// The budget lives per attempt: an ongoing load counts down its remainder, anything else
    /// resets the count. Arming again is up to whoever knows the block is awaited.
    private func updateTimeout(from previous: EmbeddedBlockState) {
        guard state != .loading || previous != .loading else { return }

        waitBudget.reset()
    }

    private func apply(_ state: EmbeddedBlockState) {
        let previous = shownAppearance
        shownAppearance = appearance(for: state)
        updatePlaceMemory(for: state)

        switch shownAppearance {
        case .collapsed, .error: hasSettled = true
        case .content: hasSettled = false
        case .placeholder: break
        }

        // Only the arrival of content is a reveal: content shown again on a return, or an error
        // screen swapped in place, changes nothing worth animating.
        let reveals = shownAppearance == .content && previous != .content
        let animated = reveals && shouldAnimateReveal

        layers.show(view(for: shownAppearance), animated: animated)

        invalidateIntrinsicContentSize()
        // The height is animated by whoever owns it: the container through its intrinsic size, a
        // wrapper laying the block out itself through its own frame.
        if animated, previous == .collapsed, appearanceObserver == nil {
            animateGrowth()
        }

        appearanceObserver?(shownAppearance)
        scheduleDelivery()
    }

    private var shouldAnimateReveal: Bool {
        animatesReveal && window != nil && !revealAnimation.isReduceMotionEnabled()
    }

    /// The new intrinsic size is already pending; laying it out inside the animation makes the host
    /// layout — Auto Layout, a stack view — grow to it instead of jumping. A list host remeasures
    /// its row on its own terms, in `mindboxEmbeddedBlockViewDidLoad`.
    private func animateGrowth() {
        revealAnimation.run(revealAnimation.duration, { [weak self] in
            self?.superview?.layoutIfNeeded()
        }, {})
    }

    /// Shown content is worth a placeholder on the next launch; a place with nothing to show is not.
    /// A failure says nothing about the place and leaves the memory as it is.
    private func updatePlaceMemory(for state: EmbeddedBlockState) {
        switch state {
        case .ready:
            placeMemory.rememberShownContent(at: placeSystemName)
        case .empty:
            placeMemory.forgetPlace(placeSystemName)
        case .loading, .failed:
            break
        }
    }

    private func appearance(for state: EmbeddedBlockState) -> MindboxEmbeddedBlockAppearance {
        switch state {
        case .ready:
            return .content
        case .empty:
            return .collapsed
        case .loading:
            return hasSettled ? settledAppearance : .placeholder
        case .failed:
            guard hasSettled else { return errorView == nil ? .collapsed : .error }

            return settledAppearance
        }
    }

    /// What a block that has ceded its space keeps showing while it waits or fails again: the error
    /// screen it already shows, or nothing. Never a placeholder — that would take the space back.
    private var settledAppearance: MindboxEmbeddedBlockAppearance {
        shownAppearance == .error && errorView != nil ? .error : .collapsed
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

        // The reason is read off the state the provider settled, never recomputed here.
        switch state {
            case .loading: break
            case .ready: delegate.mindboxEmbeddedBlockViewDidLoad(self)
            case .empty: delegate.mindboxEmbeddedBlockViewDidBecomeEmpty(self)
            case .failed(let reason): delegate.mindboxEmbeddedBlockViewDidFail(self, reason: reason)
        }
    }

    private func event(for state: EmbeddedBlockState) -> BlockEvent? {
        switch state {
            case .loading: return nil
            case .ready: return .loaded
            case .empty: return .empty
            case .failed: return .failed
        }
    }
}
