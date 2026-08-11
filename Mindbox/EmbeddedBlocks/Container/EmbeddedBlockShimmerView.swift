//
//  EmbeddedBlockShimmerView.swift
//  Mindbox
//
//  Created by vailence on 06.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// Дефолтный плейсхолдер встроенного блока — нейтральная плашка с бегущим бликом.
///
/// Заливает контейнер целиком: у SDK нет знания о вёрстке будущего контента, поэтому плейсхолдер
/// не изображает её, а просто помечает зарезервированное место как «грузится». Хост, которому
/// нужен скелет своей вёрстки, задаёт `placeholderView` контейнера.
///
/// Анимация живёт ровно столько, сколько вью видна: запускается при входе в окно и гасится при
/// выходе, включая уход приложения в фон (система снимает CA-анимации, поэтому на возврат в
/// foreground блик перезапускается).
final class EmbeddedBlockShimmerView: UIView {

    private enum Shimmer {
        static let animationKey = "embeddedBlockShimmer"
        static let animationDuration: CFTimeInterval = 1.4
    }

    private let gradientLayer = CAGradientLayer()

    private var baseColor: UIColor {
        if #available(iOS 13.0, *) {
            return .systemGray5
        }
        return UIColor(white: 0.90, alpha: 1.0)
    }

    private var highlightColor: UIColor {
        if #available(iOS 13.0, *) {
            return .systemGray6
        }
        return UIColor(white: 0.96, alpha: 1.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
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

        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.locations = [-1.0, -0.5, 0.0]
        applyColors()
        layer.addSublayer(gradientLayer)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyColors() {}}]}คิดเห็น to=multi_tool_use.parallel output format? tool returns nothing? let's check.
        gradientLayer.colors = [
            baseColor.cgColor,
            highlightColor.cgColor,
            baseColor.cgColor
        ]
    }

    private func startShimmering() {
        guard gradientLayer.animation(forKey: Shimmer.animationKey) == nil else { return }

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = Shimmer.animationDuration
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: Shimmer.animationKey)
    }

    private func stopShimmering() {
        gradientLayer.removeAnimation(forKey: Shimmer.animationKey)
    }

    /// Система снимает бесконечные CA-анимации при уходе в фон — после возврата блик нужно
    /// запустить заново.
    @objc
    private func applicationWillEnterForeground() {
        guard window != nil else { return }
        startShimmering()
    }
}
