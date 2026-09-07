//
//  EmbeddedBlockShimmerView.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// The default embedded block placeholder — the Mindbox UI Library "Shimmer": a translucent tint
/// over the host's own background with a highlight sweeping across it.
///
/// Fills the container entirely: the SDK knows nothing about the layout of the content to come, so
/// the placeholder does not depict it and simply marks the reserved spot as "loading". A host that
/// needs a skeleton of its own layout sets the container's `placeholderView`.
///
/// The design (Figma, Mobile Launchpad → "Шиммер вью для встроенных блоков") in one paragraph: the
/// shimmer is a mask, not a tile. It paints no base color of its own — a single tint (near-black in
/// light appearance, white in dark) at 8% opacity, so the same view reads on a white screen, a
/// brand color and a dark theme alike. The highlight is the only place where that opacity changes:
/// it dips to 4% in light (a lighter spot) and peaks at 16% in dark (a brighter spot). Every size
/// is a fraction of the block's width, never a point value: the same file serves an 80-point
/// avatar and a full-width banner.
///
/// Several shimmers on one screen move to one beat: each animation is anchored to a clock shared
/// by the whole process, so a block that appears later joins the sweep already in progress instead
/// of starting its own. The beat holds as long as the host leaves the layer clock alone: an ancestor
/// layer with its own `speed` or `timeOffset` shifts the shimmers under it.
///
/// What is deliberately left out is the design's layer blur. It is about 5.6% of the block's
/// width — under 2% of the gradient layer, about a tenth of the ramp it would soften — and it
/// would move an opacity that is 8% to begin with by a few hundredths. Core Animation offers no
/// public blur for a layer on iOS, and the result would be indistinguishable from the plain
/// linear ramp anyway.
final class EmbeddedBlockShimmerView: UIView {

    /// The design's numbers. Positions are fractions of the block's width (`W`).
    enum Design {

        // MARK: Color

        /// The light-appearance tint, `#282A2F`; its opacity does the work.
        static let lightTint = UIColor(red: 0x28 / 255.0, green: 0x2A / 255.0, blue: 0x2F / 255.0, alpha: 1.0)

        /// The dark-appearance tint, `#FFFFFF`.
        static let darkTint = UIColor.white

        /// The tint's opacity everywhere but the highlight, both appearances.
        static let restingAlpha: CGFloat = 0.08

        /// The highlight in light appearance dips — a spot lighter than the base.
        static let lightHighlightAlpha: CGFloat = 0.04

        /// The highlight in dark appearance peaks — a spot brighter than the base.
        static let darkHighlightAlpha: CGFloat = 0.16

        // MARK: Geometry

        /// Where the tint changes opacity, as fractions of the gradient layer's width: flat, a
        /// ramp into the highlight between 40% and 60%, flat again.
        static let stops: [CGFloat] = [0.0, 0.4, 0.5, 0.6, 1.0]

        /// The gradient layer is wider than the block so that both rest positions keep the whole
        /// ramp out of sight and the block shows a flat 8% at either end of the cycle.
        static let layerWidth: CGFloat = 2.96

        /// The gradient layer's leading edge at rest before the sweep, in `W`.
        static let startX: CGFloat = -1.88

        /// The gradient layer's leading edge at rest after the sweep, in `W`.
        static let endX: CGFloat = -0.083

        // MARK: Timing

        /// Flat at the start position before the highlight sets off.
        static let pauseAtStart: CFTimeInterval = 0.6

        /// The sweep itself, ease-in: the highlight leaves slowly and exits fast.
        static let sweepDuration: CFTimeInterval = 1.0

        /// Flat at the end position; then the layer jumps back to the start. Both rest positions
        /// look identical, so the jump is invisible and the way back is not animated.
        static let pauseAtEnd: CFTimeInterval = 0.6

        static var cycleDuration: CFTimeInterval { pauseAtStart + sweepDuration + pauseAtEnd }

        /// The stops in the block's own coordinates: `0` is its leading edge, `1` its trailing one.
        /// Moving the gradient layer by `x` is the same as shifting every stop by `x` — and stops
        /// are unit-less, so the animation never has to be rebuilt when the block is laid out.
        static func locations(forLayerAt x: CGFloat) -> [CGFloat] {
            stops.map { x + layerWidth * $0 }
        }

        static var startLocations: [CGFloat] { locations(forLayerAt: startX) }

        static var endLocations: [CGFloat] { locations(forLayerAt: endX) }

        /// The tint's opacity at each stop for the given appearance.
        static func alphas(isDark: Bool) -> [CGFloat] {
            let highlight = isDark ? darkHighlightAlpha : lightHighlightAlpha
            return [restingAlpha, restingAlpha, highlight, restingAlpha, restingAlpha]
        }

        static func colors(isDark: Bool) -> [CGColor] {
            let tint = isDark ? darkTint : lightTint
            return alphas(isDark: isDark).map { tint.withAlphaComponent($0).cgColor }
        }
    }

    // MARK: - Shared beat

    /// The instant every shimmer counts its cycle from. One per process: two blocks side by side
    /// — or a block that shows up a screen later — are at the same point of the same cycle.
    static let beatEpoch: CFTimeInterval = CACurrentMediaTime()

    // MARK: - State

    static let animationKey = "embeddedBlockShimmer"

    let gradientLayer = CAGradientLayer()

    private let notificationCenter: NotificationCenter

    /// `.unspecified` and `.light` alike take the light tint; on iOS 12 the style is always `.light`.
    private var isDarkAppearance: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    // MARK: - Life cycle

    /// - Parameter notificationCenter: Where the app's foreground notification comes from. Injected
    ///   so that tests do not have to post to the process-wide center.
    init(frame: CGRect = .zero, notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable, message: "The shimmer is not created from storyboards")
    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    /// A resize snaps: the implicit 0.25 s action a standalone sublayer gets would make the tint
    /// grow into new bounds instead of filling them at once.
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            stopShimmering()
        } else {
            startShimmering()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func setUp() {
        isUserInteractionEnabled = false
        // A mask over the host's background: nothing of its own underneath the tint.
        backgroundColor = .clear

        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.locations = Design.startLocations.map { NSNumber(value: Double($0)) }
        applyColors()
        layer.addSublayer(gradientLayer)

        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground),
                                       name: UIApplication.willEnterForegroundNotification,
                                       object: nil)
    }

    private func applyColors() {
        gradientLayer.colors = Design.colors(isDark: isDarkAppearance)
    }

    // MARK: - Animation

    private func startShimmering() {
        guard gradientLayer.animation(forKey: Self.animationKey) == nil else { return }

        gradientLayer.add(Self.makeSweep(beginningAt: gradientLayer.convertTime(Self.beatEpoch, from: nil)),
                          forKey: Self.animationKey)
    }

    private func stopShimmering() {
        gradientLayer.removeAnimation(forKey: Self.animationKey)
    }

    /// One cycle of the design, repeated forever: rest, sweep, rest, jump back.
    ///
    /// `beginTime` lies in the past for every shimmer but the very first: Core Animation then picks
    /// the cycle up at the phase the shared clock dictates rather than from the start, which is what
    /// keeps every shimmer on screen in step.
    static func makeSweep(beginningAt beginTime: CFTimeInterval) -> CAKeyframeAnimation {
        let start = Design.startLocations.map { NSNumber(value: Double($0)) }
        let end = Design.endLocations.map { NSNumber(value: Double($0)) }
        let cycle = Design.cycleDuration

        let animation = CAKeyframeAnimation(keyPath: "locations")
        animation.values = [start, start, end, end]
        animation.keyTimes = [
            0.0,
            NSNumber(value: Design.pauseAtStart / cycle),
            NSNumber(value: (Design.pauseAtStart + Design.sweepDuration) / cycle),
            1.0
        ]
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear)
        ]
        animation.duration = cycle
        animation.repeatCount = .infinity
        animation.beginTime = beginTime
        return animation
    }

    /// The system removes infinite CA animations when the app goes to the background — after
    /// coming back the sweep has to be started again. Anchored to the shared clock, it comes back
    /// at the right phase.
    @objc
    private func applicationWillEnterForeground() {
        guard window != nil else { return }
        startShimmering()
    }
}
