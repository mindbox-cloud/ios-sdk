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
/// Add it to the view hierarchy up front, not in response to an outcome: the block loads only while it
/// is in a window. Constrain its position and width; the block reports its height through
/// `intrinsicContentSize`, 0 while it is collapsed. Outcomes arrive through ``delegate``; a table or
/// collection view that sizes a row by the block must remeasure the row in each delegate call.
public final class MindboxEmbeddedBlockView: UIView {

    // MARK: - Host API

    /// The place system name from the admin panel, set at creation or in Interface Builder.
    @IBInspectable public private(set) var placeSystemName: String {
        get { setup.placeSystemName }
        set { applyInspectable("placeSystemName") { setup.placeSystemName = Self.normalizedPlaceSystemName(newValue) } }
    }

    var placeKey: String { Self.placeKey(placeSystemName) }

    /// What the block shows while it loads, set at creation or through ``loadingStrategyName``.
    public var loadingStrategy: MindboxEmbeddedBlockLoadingStrategy { setup.loadingStrategy }

    /// Whether the SDK animates the content's appearance; set `false` to animate the block's container
    /// yourself. Set at creation or in Interface Builder.
    @IBInspectable public private(set) var animatesReveal: Bool {
        get { setup.animatesReveal }
        set { applyInspectable("animatesReveal") { setup.animatesReveal = newValue } }
    }

    /// Receives the block's outcomes; a delegate set after an outcome still receives it.
    public weak var delegate: MindboxEmbeddedBlockViewDelegate? {
        didSet {
            guard delegate !== oldValue, !isReleased else { return }

            deliveredEvent = nil
            scheduleDelivery()
        }
    }

    /// The view shown while the block loads; `nil` shows the SDK's shimmer.
    public var placeholderView: UIView? {
        didSet {
            guard placeholderView !== oldValue else { return }
            refreshPlaceholder()
        }
    }

    /// The view shown when the block fails while it takes its height; `nil` collapses the block instead.
    /// Set it before the block is in a window: setting it later does not expand a collapsed block.
    public var errorView: UIView? {
        didSet {
            guard errorView !== oldValue else { return }
            refreshErrorView()
        }
    }

    // MARK: - Wrapper API

    /// Sets the observer told the block's appearance now and on each change; `nil` removes it.
    @_spi(Internal)
    public func setAppearanceObserver(_ observer: ((MindboxEmbeddedBlockAppearance) -> Void)?) {
        appearanceObserver = observer
        isRevealAnimated = false
        observer?(shownAppearance)
    }

    /// Whether the change the observer is told about is an animated reveal.
    @_spi(Internal)
    public private(set) var isRevealAnimated = false

    /// The reveal animation's duration, in seconds.
    @_spi(Internal)
    public static let revealAnimationDuration: TimeInterval = Constants.EmbeddedBlock.revealAnimationDuration

    /// Tells the block whether the wrapper shows it; a hidden block pauses.
    @_spi(Internal)
    public func setHostVisible(_ isHostVisible: Bool) {
        guard self.isHostVisible != isHostVisible else { return }

        self.isHostVisible = isHostVisible
        updateContentActivity(reason: isHostVisible ? "was shown by the host wrapper"
                                                   : "was hidden by the host wrapper")
    }

    /// Stops the block for good.
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

    /// The appearance a new block for this place and strategy starts with.
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
    ///   - placeSystemName: The place system name from the admin panel, matched ignoring letter case
    ///     and surrounding whitespace.
    ///   - height: The block's height, in points, while it is not collapsed.
    ///   - loadingStrategy: What the block shows while it loads.
    ///   - timeout: How long, in seconds, the block waits for the SDK to choose its content before it
    ///     fails with ``MindboxEmbeddedBlockFailReason/networkError``; `nil` means 30.
    ///   - animatesReveal: Whether the SDK animates the content's appearance.
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

    /// Creates a block from a storyboard or xib; see `MindboxEmbeddedBlockView+InterfaceBuilder.swift`.
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
                              layers: EmbeddedBlockLayerHost(container: self, animation: revealAnimation, coveredContent: { [weak contentProvider] in contentProvider?.coveredPageView }),
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
                && !contentProvider.isStartPending && !contentProvider.isAwaitingKeptContent && !contentProvider.owesItsPageTheSessionsData
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

    /// Returns the proposed width and the block's height, for layout with frames.
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
        case .loading, .failed, .uncheckable:
            break
        }
    }

    private func appearance(for state: EmbeddedBlockState) -> MindboxEmbeddedBlockAppearance {
        switch state {
        case .ready:
            return .content
        case .empty, .uncheckable:
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
            case .empty, .uncheckable: delegate.mindboxEmbeddedBlockViewDidBecomeEmpty(self)
            case .failed(let reason): delegate.mindboxEmbeddedBlockViewDidFail(self, reason: reason)
        }
    }

    private func event(for state: EmbeddedBlockState) -> BlockEvent? {
        switch state {
            case .loading: return nil
            case .ready: return .loaded
            case .empty, .uncheckable: return .empty
            case .failed: return .failed
        }
    }
}
