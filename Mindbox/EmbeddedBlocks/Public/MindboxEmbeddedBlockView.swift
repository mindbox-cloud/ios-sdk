//
//  MindboxEmbeddedBlockView.swift
//  Mindbox
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// A view that shows the Mindbox embedded block configured for a place in the admin panel.
///
/// Create it in code with ``init(placeSystemName:height:loadingStrategy:timeout:animatesReveal:)``
/// or in a storyboard or xib (see the Interface Builder setup in
/// `MindboxEmbeddedBlockView+InterfaceBuilder.swift`). Constrain its position and width only: the
/// block reports its own height through `intrinsicContentSize` — the height given at creation while
/// it shows content, a placeholder or ``errorView``, and 0 while it is collapsed. It collapses when
/// the place is empty or the block fails without an ``errorView``, and it can wait collapsed while
/// it loads; see ``loadingStrategy``. A table or collection view that sizes a row by the block
/// should remeasure the row in every ``delegate`` call.
///
/// The SDK decides what the block shows and loads it while the block is in a window. When the
/// block leaves the window, it pauses on the next main-queue turn unless it is back in a window by
/// then, and resumes when it returns. A failed block tries again when it re-enters a window, or
/// when the app returns from the background with the block on screen. While it retries it stays
/// collapsed or keeps its ``errorView``; content replaces the error view, and a place that turns
/// out to have nothing to show collapses the block. Outcomes reach the host only through ``delegate``.
///
/// While content is shown, a later answer without content, or new data its page renders as nothing,
/// waits until the block leaves the window, even while the app is in the background: only then does the
/// block apply it (collapse, or show ``errorView`` for a failure) and report it. Such an answer to
/// an operation the app sends is applied at once.
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The place system name from the admin panel, without surrounding whitespace; the letter case
    /// is kept as given. The SDK matches the place ignoring the case.
    ///
    /// Set at creation or in Interface Builder. A key-value write after the block is built is
    /// ignored and logged as an error.
    @IBInspectable public private(set) var placeSystemName: String {
        get { setup.placeSystemName }
        set { applyInspectable("placeSystemName") { setup.placeSystemName = Self.normalizedPlaceSystemName(newValue) } }
    }

    var placeKey: String { Self.placeKey(placeSystemName) }

    /// What the block shows while its content loads, set at creation or through
    /// ``loadingStrategyName``. See ``MindboxEmbeddedBlockLoadingStrategy``.
    public var loadingStrategy: MindboxEmbeddedBlockLoadingStrategy { setup.loadingStrategy }

    /// Whether the content fades in and a collapsed block grows to its height when content arrives.
    /// `false`, or Reduce Motion, shows the content and applies the height at once, for a host that
    /// animates the block's container itself.
    ///
    /// Set at creation or in Interface Builder, like ``placeSystemName``.
    @IBInspectable public private(set) var animatesReveal: Bool {
        get { setup.animatesReveal }
        set { applyInspectable("animatesReveal") { setup.animatesReveal = newValue } }
    }

    /// Receives the block's outcomes: loaded, empty or failed. Held weakly.
    ///
    /// Each outcome arrives asynchronously on the main queue, when `intrinsicContentSize` already
    /// reports the new height. A delegate assigned after the block has an outcome receives it,
    /// including the same delegate set again after `nil`; assigning the delegate that is already set
    /// does nothing. A retry that ends in the outcome the delegate heard last is not reported again.
    public weak var delegate: MindboxEmbeddedBlockViewDelegate? {
        didSet {
            guard delegate !== oldValue, !isReleased else { return }

            deliveredEvent = nil
            scheduleDelivery()
        }
    }

    /// The view shown while the content loads; `nil` (the default) shows the SDK's shimmer.
    ///
    /// The block pins the view to its edges with Auto Layout. It can be replaced at any time,
    /// including while it is shown. A block that waits collapsed while it loads shows no
    /// placeholder; see ``loadingStrategy``.
    public var placeholderView: UIView? {
        didSet {
            guard placeholderView !== oldValue else { return }
            refreshPlaceholder()
        }
    }

    /// The view shown when the block fails; `nil` (the default) collapses the block instead. The
    /// SDK has no error view of its own.
    ///
    /// A block that shows a placeholder or content when it fails keeps its height and shows this
    /// view, pinned to its edges. A block that is collapsed when it fails stays collapsed. An empty
    /// place always collapses the block.
    ///
    /// Replacing the view while it is shown swaps it; setting `nil` then collapses the block.
    /// Setting a view on a collapsed block does not expand it: the view applies to a failure that
    /// happens after the block shows content.
    public var errorView: UIView? {
        didSet {
            guard errorView !== oldValue else { return }
            refreshErrorView()
        }
    }

    // MARK: - Wrapper API

    /// Sets the observer told how the block occupies its place, for wrappers that lay the block out
    /// themselves instead of relying on `intrinsicContentSize`; `nil` removes it.
    ///
    /// The observer receives the current `MindboxEmbeddedBlockAppearance` inside this call, then
    /// again each time the block applies a state, which can repeat the same appearance. While an
    /// observer is set, the block animates only the fade of its content; the wrapper animates the
    /// height.
    @_spi(Internal)
    public func setAppearanceObserver(_ observer: ((MindboxEmbeddedBlockAppearance) -> Void)?) {
        appearanceObserver = observer
        isRevealAnimated = false
        observer?(shownAppearance)
    }

    /// Whether the appearance the observer is being told about is an animated reveal. Valid only
    /// inside the observer.
    @_spi(Internal)
    public private(set) var isRevealAnimated = false

    /// The duration of the reveal animation, for a wrapper that animates its own layout to match.
    @_spi(Internal)
    public static let revealAnimationDuration: TimeInterval = Constants.EmbeddedBlock.revealAnimationDuration

    /// Tells the block whether the wrapper shows it, for wrappers whose screens share one window,
    /// such as Flutter, where leaving a screen does not take the block out of the window.
    ///
    /// The block runs only while it is in a window and shown by the wrapper; `true` by default.
    /// Hiding pauses the block the way leaving a window does — it keeps its page and the time left
    /// of its timeout — but at once rather than on the next main-queue turn. Passing the current
    /// value does nothing.
    @_spi(Internal)
    public func setHostVisible(_ isHostVisible: Bool) {
        guard self.isHostVisible != isHostVisible else { return }

        self.isHostVisible = isHostVisible
        updateContentActivity(reason: isHostVisible ? "was shown by the host wrapper"
                                                   : "was hidden by the host wrapper")
    }

    /// Stops the block for good and drops its page: it does not start again, even in a window.
    /// Calling it again does nothing.
    ///
    /// The appearance observer is dropped first. An outcome the delegate has not heard yet,
    /// including one held until the block leaves the window, reaches the delegate inside this call;
    /// then the delegate is dropped. Without this call `deinit` does the same cleanup, but the
    /// delegate hears nothing from it.
    @_spi(Internal)
    public func release() {
        guard !isReleased else { return }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was released by the host wrapper",
                      category: .embeddedBlocks)
        isReleased = true
        appearanceObserver = nil
        updateContentActivity(reason: "was released by the host wrapper")
        if isDeliveryScheduled { deliverPendingEvent() }
        delegate = nil
        runtime?.contentProvider.teardown()
    }

    /// The appearance a new block for this place and strategy starts with, for wrappers that size
    /// the block before creating it.
    @_spi(Internal)
    public static func initialAppearance(placeSystemName: String,
                                         loadingStrategy: MindboxEmbeddedBlockLoadingStrategy) -> MindboxEmbeddedBlockAppearance {
        guard loadingStrategy == .automatic else {
            return initialAppearance(for: loadingStrategy, hasShownContentBefore: false)
        }

        let memory = DI.injectOrFail(EmbeddedBlockPlaceRemembering.self)
        return initialAppearance(for: loadingStrategy, hasShownContentBefore: memory.hasShownContent(at: placeKey(placeSystemName)))
    }

    // MARK: - State

    var setup = EmbeddedBlockSetup()

    private struct Runtime {
        let contentProvider: EmbeddedBlockWebViewProvider
        let placeMemory: EmbeddedBlockPlaceRemembering
        let revealAnimation: EmbeddedBlockRevealAnimation
        let waitBudget: EmbeddedBlockWaitBudget
        let layers: EmbeddedBlockLayerHost
        let afterMainPass: (@escaping () -> Void) -> Void
    }

    private var runtime: Runtime?

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
            if case .failed = state { Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': content failed — \(shownAppearance == .error ? "showing the host's error view" : "collapsing")",
                                                    category: .embeddedBlocks) }
        }
    }

    private var hasSettled = true

    private var shownAppearance: MindboxEmbeddedBlockAppearance = .collapsed

    private var appearanceObserver: ((MindboxEmbeddedBlockAppearance) -> Void)?

    private var isHostVisible = true

    private var isReleased = false

    private var isContentRunning = false

    private enum BlockEvent {
        case loaded
        case empty
        case failed
    }

    private var deliveredEvent: BlockEvent?

    private var isDeliveryScheduled = false

    // MARK: - Life cycle

    /// Creates a block for a place.
    ///
    /// - Parameters:
    ///   - placeSystemName: The place system name from the admin panel. Surrounding whitespace and
    ///     letter case are ignored: `Main-Screen-Top` and `main-screen-top` are the same place.
    ///   - height: The height the block takes while it shows content, a placeholder or
    ///     ``errorView``. 0 or less keeps the block invisible and is logged as an error.
    ///   - loadingStrategy: What the block shows while its content loads; see
    ///     ``MindboxEmbeddedBlockLoadingStrategy``.
    ///   - timeout: How long, in seconds, the block waits for the SDK to choose its content before
    ///     it fails with ``MindboxEmbeddedBlockFailReason/networkError``. Only time in a window with
    ///     the app in the foreground counts. `nil` means 30; 0 or less is logged as an error and
    ///     means 30 too. An answer that arrives later is dropped. Once the content is chosen, its
    ///     page has a separate time limit to render, which this value does not change.
    ///   - animatesReveal: Whether the reveal of the content is animated; see ``animatesReveal``.
    public convenience init(placeSystemName: String,
                            height: CGFloat,
                            loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic,
                            timeout: TimeInterval? = nil,
                            animatesReveal: Bool = true) {
        let place = Self.normalizedPlaceSystemName(placeSystemName)
        self.init(placeSystemName: place,
                  height: height,
                  contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(placeSystemName: Self.placeKey(place)),
                  placeMemory: DI.injectOrFail(EmbeddedBlockPlaceRemembering.self),
                  loadingStrategy: loadingStrategy,
                  timeout: timeout,
                  animatesReveal: animatesReveal)
    }

    /// Creates a block from a storyboard or xib. Interface Builder sets the inspectable properties
    /// next, and the block builds itself from them in `awakeFromNib()`; see the Interface Builder
    /// setup in `MindboxEmbeddedBlockView+InterfaceBuilder.swift`.
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
         makeWaitBudget: ((_ placeSystemName: String, _ duration: @escaping () -> TimeInterval) -> EmbeddedBlockWaitBudget)? = nil,
         afterMainPass: @escaping (@escaping () -> Void) -> Void = MindboxEmbeddedBlockView.onTheNextMainPass) {
        self.setup = EmbeddedBlockSetup(placeSystemName: placeSystemName,
                                        loadingStrategy: loadingStrategy,
                                        timeout: Self.sanitizedTimeout(timeout, placeSystemName: placeSystemName),
                                        animatesReveal: animatesReveal)
        self.preferredHeight = height
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = .clear
        build(contentProvider: contentProvider,
              placeMemory: placeMemory,
              revealAnimation: revealAnimation,
              makeWaitBudget: makeWaitBudget,
              afterMainPass: afterMainPass)
    }

    func build(contentProvider: EmbeddedBlockWebViewProvider,
               placeMemory: EmbeddedBlockPlaceRemembering,
               revealAnimation: EmbeddedBlockRevealAnimation,
               makeWaitBudget: ((_ placeSystemName: String, _ duration: @escaping () -> TimeInterval) -> EmbeddedBlockWaitBudget)?,
               afterMainPass: @escaping (@escaping () -> Void) -> Void) {
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
                              layers: EmbeddedBlockLayerHost(container: self, animation: revealAnimation),
                              afterMainPass: afterMainPass)
        self.runtime = runtime

        let initial = Self.initialAppearance(for: loadingStrategy,
                                             hasShownContentBefore: placeMemory.hasShownContent(at: placeKey))
        self.shownAppearance = initial
        self.hasSettled = initial == .collapsed
        warnAboutSetup()
        logInitialLook()
        setUpContainer(runtime)
    }

    private func logInitialLook() {
        let look = shownAppearance == .collapsed ? "hidden, taking no space" : "a placeholder"
        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' starts with \(look) (strategy \(loadingStrategy))",
                      category: .embeddedBlocks)
    }

    deinit {
        runtime?.waitBudget.pause()
        if let held = runtime?.contentProvider.heldCollapse {
            updatePlaceMemory(for: held)
        }
        runtime?.contentProvider.teardown()
    }

    private func setUpContainer(_ runtime: Runtime) {
        let contentProvider = runtime.contentProvider
        let waitBudget = runtime.waitBudget

        contentProvider.onStateChange = { [weak self] state in
            self?.state = state
        }

        contentProvider.onContentArrived = {
            waitBudget.reset()
            waitBudget.armIfNeeded()
        }

        contentProvider.onContentDelayed = {
            waitBudget.reset()
        }

        contentProvider.onStarted = {
            waitBudget.armIfNeeded()
        }

        contentProvider.onKeptContentChanged = {
            waitBudget.refresh()
        }

        contentProvider.isOnScreen = { [weak self] in self?.isEffectivelyVisible == true }

        waitBudget.isNeeded = { [weak self, weak contentProvider] in
            guard let self, let contentProvider else { return false }
            return self.isContentRunning && self.state == .loading && !contentProvider.isAwaitingDelayedContent
                && !contentProvider.isStartPending && !contentProvider.isAwaitingKeptContent
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

    /// Returns the proposed width and the same height as `intrinsicContentSize`, for hosts that lay
    /// out with frames.
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

        if !isReleased {
            buildIfNeeded()
        }

        guard window == nil else {
            updateContentActivity(reason: "entered the window")
            return
        }

        runtime?.afterMainPass { [weak self] in
            self?.updateContentActivity(reason: "left the window")
        }
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
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' \(reason), \(isReleased ? "stopping" : "pausing") content",
                          category: .embeddedBlocks)
            runtime.waitBudget.pause()
            runtime.contentProvider.stop()
        }
    }

    func reload() {
        guard let runtime, isContentRunning else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload skipped: the block is not on screen",
                          category: .embeddedBlocks)
            return
        }

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' reload requested", category: .embeddedBlocks)
        runtime.waitBudget.reset()
        deliveredEvent = nil
        resetToInitialLook(runtime)
        runtime.contentProvider.reload()
        runtime.waitBudget.armIfNeeded()
    }

    private func resetToInitialLook(_ runtime: Runtime) {
        let initial = Self.initialAppearance(for: loadingStrategy,
                                             hasShownContentBefore: runtime.placeMemory.hasShownContent(at: placeKey))
        shownAppearance = initial
        hasSettled = initial == .collapsed
    }

    private func handleTimeout() {
        guard let runtime else { return }

        if runtime.contentProvider.isAwaitingAnswer {
            runtime.contentProvider.failUnanswered(waited: runtime.waitBudget.consumed)
        } else {
            runtime.contentProvider.failSilentPage()
        }
    }

    // MARK: - Layers

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

        let reveals = shownAppearance == .content && previous != .content
        let animated = reveals && shouldAnimateReveal

        runtime.layers.show(view(for: shownAppearance), animated: animated)

        if animated, previous == .collapsed, appearanceObserver == nil {
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

    private func animateGrowth(_ revealAnimation: EmbeddedBlockRevealAnimation) {
        revealAnimation.run(revealAnimation.duration, { [weak self] in
            self?.window?.layoutIfNeeded()
        }, {})
    }

    private func updatePlaceMemory(for state: EmbeddedBlockState) {
        switch state {
        case .ready:
            runtime?.placeMemory.rememberShownContent(at: placeKey)
        case .empty:
            runtime?.placeMemory.forgetPlace(placeKey)
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

        Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)': the host replaced the error view", category: .embeddedBlocks)
        apply(state)
    }

    // MARK: - Host events

    // Next main turn: the state can change mid-layout-pass, and host code called from there breaks the host's layout.
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
