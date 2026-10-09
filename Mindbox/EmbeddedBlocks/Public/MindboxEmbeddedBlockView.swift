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
/// should occupy — from code through `init(placeSystemName:height:)`, or from a storyboard or xib
/// with the same values given in the Attributes Inspector; see `MindboxEmbeddedBlockView+InterfaceBuilder`.
/// Put it anywhere in the app and constrain its position and width only — the height is applied
/// by the container itself through `intrinsicContentSize`: the one given at creation while the
/// content is shown, and 0 when there is nothing to show (a failure or an empty block), so the
/// block takes no space and is invisible in the host layout. Whether it takes that height while
/// the content is loading is decided by `loadingStrategy`, given at creation: a placeholder,
/// nothing, or — by default — nothing until the place has shown content once on this device and a
/// placeholder from then on.
/// Both looks can be customized: `placeholderView` replaces the stock loading shimmer, and
/// `errorView` opts into showing a failure instead of collapsing.
///
/// The content is revealed with the SDK's own animation — it fades in, and a block that started
/// hidden grows to its height — unless `animatesReveal` is off. A host that wants an animation of its
/// own turns that off, puts the block in a container of its own and animates the container in
/// `mindboxEmbeddedBlockViewDidLoad`.
///
/// A block that waited hidden changes its height on `mindboxEmbeddedBlockViewDidLoad`: from 0 to the
/// height given at creation. A host that measures the block itself — a table or a collection view
/// remeasuring its row — does so on that call as well, not only on empty and failure; a row measured
/// once before the content arrived would stay at zero.
///
/// What exactly lives inside is decided by the SDK from the `placeSystemName`, not by the host. The
/// block flow belongs to the SDK too: the container starts its content when it enters a window
/// and stops it when it leaves. The host app observes the outcome through `delegate` and nothing
/// else: the block is shown, the place is empty, or the block failed with a reason.
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The system name of the place from the admin panel, given at creation and stripped of the
    /// whitespace around it. Decides what content the SDK puts inside.
    ///
    /// Written by Interface Builder only, before the block is built; read-only for the host, like
    /// on Android. A key-value write once the block is built is ignored and reported.
    @IBInspectable public private(set) var placeSystemName: String {
        get { setup.placeSystemName }
        set { applyInspectable("placeSystemName") { setup.placeSystemName = Self.normalizedPlaceSystemName(newValue) } }
    }

    /// What the block shows until the SDK answers, given at creation.
    /// See `MindboxEmbeddedBlockLoadingStrategy`.
    public var loadingStrategy: MindboxEmbeddedBlockLoadingStrategy { setup.loadingStrategy }

    /// Whether the SDK animates the reveal of the content, given at creation. `false` swaps the layers
    /// and applies the height at once — for a host that animates the block's container itself. The
    /// system's Reduce Motion setting turns the animation off as well.
    ///
    /// Written by Interface Builder only, like `placeSystemName`.
    @IBInspectable public private(set) var animatesReveal: Bool {
        get { setup.animatesReveal }
        set { applyInspectable("animatesReveal") { setup.animatesReveal = newValue } }
    }

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
    /// mid-loading. A block that waits hidden — see `loadingStrategy` — shows no placeholder until
    /// it has shown content: from then on it keeps its space in the placeholder while its page is
    /// replaced.
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
        isRevealAnimated = false
        observer?(shownAppearance)
    }

    /// Whether the look the observer is being told about is the animated reveal. Valid only
    /// inside the observer: the next look overwrites it.
    @_spi(Internal)
    public private(set) var isRevealAnimated = false

    /// How long the reveal takes, for a wrapper that animates its own frame.
    @_spi(Internal)
    public static let revealAnimationDuration: TimeInterval = Constants.EmbeddedBlock.revealAnimationDuration

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
        // A decoded block that was never built has no content to tear down.
        runtime?.contentProvider.teardown()
    }

    /// The look a block of this place starts with, for wrappers that size the block before the
    /// container exists: a hidden start must not be preceded by a frame of reserved space.
    @_spi(Internal)
    public static func initialAppearance(placeSystemName: String,
                                         loadingStrategy: MindboxEmbeddedBlockLoadingStrategy) -> MindboxEmbeddedBlockAppearance {
        // Only `automatic` asks the memory; the other two are decided by the strategy alone.
        guard loadingStrategy == .automatic else {
            return initialAppearance(for: loadingStrategy, hasShownContentBefore: false)
        }

        let place = normalizedPlaceSystemName(placeSystemName)
        let memory = DI.injectOrFail(EmbeddedBlockPlaceRemembering.self)
        return initialAppearance(for: loadingStrategy, hasShownContentBefore: memory.hasShownContent(at: place))
    }

    // MARK: - State

    /// What the block was given at creation: by the initializer, or by Interface Builder between
    /// `init(coder:)` and `awakeFromNib`.
    var setup = EmbeddedBlockSetup()

    /// Everything a built block runs on. One optional for the whole set: a block has all of it or
    /// none of it, and "none" — between `init(coder:)` and the build in `awakeFromNib` or the
    /// window — is checked in one place per entry point instead of being a crash in each.
    private struct Runtime {
        let contentProvider: EmbeddedBlockWebViewProvider
        let placeMemory: EmbeddedBlockPlaceRemembering
        let revealAnimation: EmbeddedBlockRevealAnimation
        let waitBudget: EmbeddedBlockWaitBudget
        let layers: EmbeddedBlockLayerHost
    }

    private var runtime: Runtime?

    /// Whether the block has its dependencies and runs: right after the initializer for a block
    /// from code, after `awakeFromNib` for one from a nib. The setup is frozen from then on.
    var isBuilt: Bool { runtime != nil }

    var preferredHeight: CGFloat = 0 {
        didSet {
            guard preferredHeight != oldValue else { return }

            invalidateIntrinsicContentSize()
        }
    }

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
    private var hasSettled = true

    private var shownAppearance: MindboxEmbeddedBlockAppearance = .collapsed

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
    ///   - height: The height the block occupies when shown — and while loading, unless it waits
    ///     hidden by its `loadingStrategy`. Reserving it is the host's job and there is no default:
    ///     a height of 0 or less leaves the block invisible whatever its content turns out to be,
    ///     so the SDK reports it as an integration error.
    ///   - loadingStrategy: What the block shows until the SDK answers: a placeholder, nothing, or
    ///     `automatic` — the default — hidden until the place has shown content once on this device
    ///     and a placeholder from then on.
    ///   - timeout: How long the block waits to learn what it shows — the config has to
    ///     arrive and the selection has to run — before failing as `networkError`, in seconds;
    ///     `errorView` applies unless the block waited hidden. `nil` means the SDK default of 30. An answer that arrives after
    ///     that no longer expands the block; the next attempt starts when the block enters the
    ///     window again. The separate budget a loaded page gets to render itself is not affected.
    ///   - animatesReveal: Whether the SDK animates the reveal of the content. `true` by default;
    ///     the system's Reduce Motion setting turns the animation off as well.
    public convenience init(placeSystemName: String,
                            height: CGFloat,
                            loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic,
                            timeout: TimeInterval? = nil,
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

    /// A block from a storyboard or xib. Interface Builder applies the inspectables next, and the
    /// block builds itself in `awakeFromNib` — see `MindboxEmbeddedBlockView+InterfaceBuilder`.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
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
        self.setup = EmbeddedBlockSetup(placeSystemName: placeSystemName,
                                        loadingStrategy: loadingStrategy,
                                        timeout: Self.sanitizedTimeout(timeout, placeSystemName: placeSystemName),
                                        animatesReveal: animatesReveal)
        self.preferredHeight = height
        super.init(frame: .zero)
        // The look of a block from code is the SDK's: transparent, so the host's background shows
        // through the page, and clipping. A block from a nib keeps what Interface Builder gave it.
        clipsToBounds = true
        backgroundColor = .clear
        build(contentProvider: contentProvider,
              placeMemory: placeMemory,
              revealAnimation: revealAnimation,
              makeWaitBudget: makeWaitBudget)
    }

    /// The one place a block gets its dependencies: right away from the initializer, in
    /// `awakeFromNib` for a block from a nib. Once — a second call changes nothing.
    /// See `MindboxEmbeddedBlockView+InterfaceBuilder`.
    func build(contentProvider: EmbeddedBlockWebViewProvider,
               placeMemory: EmbeddedBlockPlaceRemembering,
               revealAnimation: EmbeddedBlockRevealAnimation,
               makeWaitBudget: ((_ placeSystemName: String, _ duration: @escaping () -> TimeInterval) -> EmbeddedBlockWaitBudget)?) {
        guard runtime == nil else { return }

        let answerTimeout = setup.timeout
        let duration: () -> TimeInterval = { [weak contentProvider] in
            contentProvider?.isAwaitingAnswer == false
                ? TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
                : answerTimeout
        }
        let runtime = Runtime(contentProvider: contentProvider,
                              placeMemory: placeMemory,
                              revealAnimation: revealAnimation,
                              waitBudget: makeWaitBudget?(placeSystemName, duration)
                                  ?? EmbeddedBlockWaitBudget(placeSystemName: placeSystemName, duration: duration),
                              layers: EmbeddedBlockLayerHost(container: self, animation: revealAnimation))
        self.runtime = runtime

        // Decided synchronously, before the first layout pass: a wrapper reads the same answer
        // through `initialAppearance(placeSystemName:loadingStrategy:)`.
        let initial = Self.initialAppearance(for: loadingStrategy,
                                             hasShownContentBefore: placeMemory.hasShownContent(at: placeSystemName))
        self.shownAppearance = initial
        self.hasSettled = initial == .collapsed
        warnAboutSetup()
        logInitialLook()
        setUpContainer(runtime)
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

    private func logInitialLook() {
        let look = shownAppearance == .collapsed ? "hidden, taking no space" : "a placeholder"
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' starts with \(look) (strategy \(loadingStrategy))",
                      category: .embeddedBlocks)
    }

    deinit {
        // A nib-loaded block let go before `awakeFromNib` has nothing to stop.
        runtime?.waitBudget.pause()
        runtime?.contentProvider.teardown()
    }

    private func setUpContainer(_ runtime: Runtime) {
        let contentProvider = runtime.contentProvider
        let waitBudget = runtime.waitBudget

        contentProvider.onStateChange = { [weak self] state in
            self?.state = state
        }

        // The wait changes its nature once content arrives: the budget starts over with the page's
        // own — shorter — patience.
        contentProvider.onContentArrived = {
            waitBudget.reset()
            waitBudget.armIfNeeded()
        }

        // Known content on its way is not silence: the budget stands down until the page starts loading.
        contentProvider.onContentDelayed = {
            waitBudget.reset()
        }

        waitBudget.isNeeded = { [weak self, weak contentProvider] in
            guard let self, let contentProvider else { return false }
            return self.isEffectivelyVisible && self.state == .loading && !contentProvider.isAwaitingDelayedContent
        }
        waitBudget.onExpire = { [weak self] in
            self?.handleTimeout()
        }

        runtime.layers.show(view(for: shownAppearance))
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

        // A view decoded outside a nib — an archive clone, say — never got `awakeFromNib`: the
        // window is the last moment to build it before the content is asked to start. A released
        // block is not built: nothing will ever show it.
        if !isReleased {
            buildIfNeeded()
        }
        updateContentActivity(reason: window == nil ? "left the window" : "entered the window")
    }

    private func updateContentActivity(reason: String) {
        guard let runtime else { return }

        let shouldRun = isEffectivelyVisible

        guard shouldRun != isContentRunning else { return }

        isContentRunning = shouldRun

        if shouldRun {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' \(reason), starting content",
                          category: .embeddedBlocks)
            runtime.contentProvider.start()
            runtime.waitBudget.armIfNeeded()
        } else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' \(reason), stopping content",
                          category: .embeddedBlocks)
            // A pause, not a reset: leaving the window does not cancel an attempt already started.
            runtime.waitBudget.pause()
            runtime.contentProvider.stop()
        }
    }

    /// Internal and without a public wrapper: automatic reloads — on failure, on returning to the
    /// app — will be built on this method.
    func reload() {
        guard let runtime, isEffectivelyVisible else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload skipped: the block is not on screen",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload requested", category: .embeddedBlocks)
        runtime.waitBudget.reset()
        // A new attempt means a new outcome: the host must hear it even if it matches the previous one.
        deliveredEvent = nil
        // A reload starts the cycle over from the block's first look: the strategy decides again —
        // the place's memory as it is now included — whether the block waits in a placeholder or hidden.
        resetToInitialLook(runtime)
        runtime.contentProvider.reload()
        runtime.waitBudget.armIfNeeded()
    }

    private func resetToInitialLook(_ runtime: Runtime) {
        let initial = Self.initialAppearance(for: loadingStrategy,
                                             hasShownContentBefore: runtime.placeMemory.hasShownContent(at: placeSystemName))
        shownAppearance = initial
        hasSettled = initial == .collapsed
    }

    /// Both a page that was built and stayed silent and a block the SDK never answered fail — with
    /// different reasons, decided by the provider next to the failure report. The state arrives
    /// through `onStateChange`, reason attached; the provider also abandons the attempt so it cannot
    /// resurrect content the container has given up on.
    private func handleTimeout() {
        guard let runtime else { return }

        if runtime.contentProvider.isAwaitingAnswer {
            runtime.contentProvider.failUnanswered(waited: runtime.waitBudget.consumed)
        } else {
            runtime.contentProvider.failSilentPage()
        }
    }

    // MARK: - Layers

    /// The budget lives per attempt: an ongoing load counts down its remainder, anything else
    /// resets the count. Arming again is up to whoever knows the block is awaited.
    private func updateTimeout(from previous: EmbeddedBlockState) {
        guard state != .loading || previous != .loading else { return }

        runtime?.waitBudget.reset()
    }

    private func apply(_ state: EmbeddedBlockState) {
        guard let runtime else { return }

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

        runtime.layers.show(view(for: shownAppearance), animated: animated)

        // The height is animated by whoever owns it: the container through its intrinsic size, a
        // wrapper laying the block out itself through its own frame.
        if animated, previous == .collapsed, appearanceObserver == nil {
            // Whatever the host had pending settles first, outside the animation: only the growth
            // of the block is animated.
            window?.layoutIfNeeded()
            invalidateIntrinsicContentSize()
            animateGrowth(runtime.revealAnimation)
        } else {
            invalidateIntrinsicContentSize()
        }

        isRevealAnimated = animated
        appearanceObserver?(shownAppearance)
        scheduleDelivery()
    }

    private var shouldAnimateReveal: Bool {
        guard let runtime else { return false }

        return animatesReveal && window != nil && !runtime.revealAnimation.isReduceMotionEnabled()
    }

    /// The new intrinsic size is already pending; laying it out inside the animation makes the host
    /// layout — Auto Layout, a stack view — grow to it instead of jumping. From the window, not the
    /// superview: the growth moves everything below the block, and a superview laid out on its own
    /// leaves its ancestors to jump after the animation. A list host remeasures its row on its own
    /// terms, in `mindboxEmbeddedBlockViewDidLoad`.
    private func animateGrowth(_ revealAnimation: EmbeddedBlockRevealAnimation) {
        revealAnimation.run(revealAnimation.duration, { [weak self] in
            self?.window?.layoutIfNeeded()
        }, {})
    }

    /// Shown content is worth a placeholder on the next launch; a place with nothing to show is not.
    /// A failure says nothing about the place and leaves the memory as it is.
    private func updatePlaceMemory(for state: EmbeddedBlockState) {
        switch state {
        case .ready:
            runtime?.placeMemory.rememberShownContent(at: placeSystemName)
        case .empty:
            runtime?.placeMemory.forgetPlace(placeSystemName)
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
            // A block that ceded its space keeps what it shows. One that holds its place — showing
            // content, or already waiting in a placeholder for a replaced page — keeps that space in
            // a placeholder, whatever the strategy: shrinking to nothing and growing back would be a
            // jump for no reason. The first wait is the strategy's call, made through `hasSettled`
            // at creation and on `reload()`.
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
        case .content: return runtime?.contentProvider.contentView
        case .error: return errorView
        case .collapsed: return nil
        }
    }

    private func refreshPlaceholder() {
        guard shownAppearance == .placeholder else { return }
        runtime?.layers.show(view(for: .placeholder))
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
