//
//  EmbeddedBlockShimmerView.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

final class EmbeddedBlockShimmerView: UIView {

    /// Positions are fractions of the block's width.
    enum Design {

        static let lightTint = UIColor(red: 0x28 / 255.0, green: 0x2A / 255.0, blue: 0x2F / 255.0, alpha: 1.0)
        static let darkTint = UIColor.white

        static let restingAlpha: CGFloat = 0.08
        static let lightHighlightAlpha: CGFloat = 0.04
        static let darkHighlightAlpha: CGFloat = 0.16

        static let stops: [CGFloat] = [0.0, 0.4, 0.5, 0.6, 1.0]
        static let layerWidth: CGFloat = 2.96
        static let startX: CGFloat = -1.88
        static let endX: CGFloat = -0.083

        static let pauseAtStart: CFTimeInterval = 0.6
        static let sweepDuration: CFTimeInterval = 1.0
        static let pauseAtEnd: CFTimeInterval = 0.6

        static var cycleDuration: CFTimeInterval { pauseAtStart + sweepDuration + pauseAtEnd }

        static func locations(forLayerAt x: CGFloat) -> [CGFloat] {
            stops.map { x + layerWidth * $0 }
        }

        static var startLocations: [CGFloat] { locations(forLayerAt: startX) }

        static var endLocations: [CGFloat] { locations(forLayerAt: endX) }

        static func alphas(isDark: Bool) -> [CGFloat] {
            let highlight = isDark ? darkHighlightAlpha : lightHighlightAlpha
            return [restingAlpha, restingAlpha, highlight, restingAlpha, restingAlpha]
        }

        static func colors(isDark: Bool) -> [CGColor] {
            let tint = isDark ? darkTint : lightTint
            return alphas(isDark: isDark).map { tint.withAlphaComponent($0).cgColor }
        }
    }

    /// One per process so every shimmer on screen sweeps in the same phase.
    static let beatEpoch: CFTimeInterval = CACurrentMediaTime()

    static let animationKey = "embeddedBlockShimmer"

    let gradientLayer = CAGradientLayer()

    private let notificationCenter: NotificationCenter

    private var isDarkAppearance: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

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

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
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
        backgroundColor = .clear

        gradientLayer.actions = ["bounds": NSNull(), "position": NSNull()]
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

    private func startShimmering() {
        guard gradientLayer.animation(forKey: Self.animationKey) == nil else { return }

        gradientLayer.add(Self.makeSweep(beginningAt: gradientLayer.convertTime(Self.beatEpoch, from: nil)),
                          forKey: Self.animationKey)
    }

    private func stopShimmering() {
        gradientLayer.removeAnimation(forKey: Self.animationKey)
    }

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

    // The system drops infinite animations while the app is in the background.
    @objc
    private func applicationWillEnterForeground() {
        guard window != nil else { return }
        startShimmering()
    }
}
