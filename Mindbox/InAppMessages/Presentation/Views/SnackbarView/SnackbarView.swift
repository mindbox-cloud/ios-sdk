//  SnackbarView.swift
//  Mindbox
//
//  Created by vailence on 15.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

class SnackbarView: UIView {

    // MARK: Public properties

    public var swipeDirection: UISwipeGestureRecognizer.Direction = .down

    // MARK: Private properties

    private let onClose: () -> Void
    private let animationTime: TimeInterval

    private var safeAreaInset: (top: CGFloat, bottom: CGFloat) {
        (
            top: window?.safeAreaInsets.top ?? Constants.defaultSafeAreaTopInset,
            bottom: window?.safeAreaInsets.bottom ?? Constants.defaultSafeAreaBottomInset
        )
    }

    private enum Constants {
        static let defaultAnimationTime: TimeInterval = 0.3
        static let swipeThresholdFraction: CGFloat = 0.5
        static let defaultSafeAreaTopInset: CGFloat = .zero
        static let defaultSafeAreaBottomInset: CGFloat = .zero
        static let noHorizontalTranslation: CGFloat = .zero
        static let noVerticalTranslation: CGFloat = .zero
        static let verticalMovementThreshold: CGFloat = .zero
    }

    // MARK: Init

    init(onClose: @escaping () -> Void,
         animationTime: TimeInterval = Constants.defaultAnimationTime) {
        self.onClose = onClose
        self.animationTime = animationTime
        super.init(frame: .zero)
        setupPanGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public methods

    public func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        animateHide(completion: {
            self.onClose()
            completion?()
        }, animated: animated)
    }

    // MARK: Private methods

    private func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        self.addGestureRecognizer(panGesture)
    }

    @objc
    private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .changed:
            handleSwipeGesture(translation: translation)
        case .ended, .cancelled:
            finalizeGesture(translation: translation)
        default:
            break
        }
    }

    private func handleSwipeGesture(translation: CGPoint) {
        if (swipeDirection == .up && translation.y < Constants.verticalMovementThreshold) ||
            (swipeDirection == .down && translation.y > Constants.verticalMovementThreshold) {
            self.transform = CGAffineTransform(translationX: Constants.noHorizontalTranslation, y: translation.y)
        }
    }

    private func finalizeGesture(translation: CGPoint) {
        let threshold = frame.height * Constants.swipeThresholdFraction +
        (swipeDirection == .up ? safeAreaInset.top : safeAreaInset.bottom)

        if ((swipeDirection == .up && translation.y < Constants.verticalMovementThreshold) ||
            (swipeDirection == .down && translation.y > Constants.verticalMovementThreshold)
        ) && abs(translation.y) > threshold {
            animateHide(completion: onClose, animated: true)
        } else {
            UIView.animate(withDuration: animationTime) {
                self.transform = .identity
            }
        }
    }

    private func animateHide(completion: @escaping () -> Void, animated: Bool) {
        if animated {
            UIView.animate(withDuration: animationTime) {
                self.setHiddenTransform()
            } completion: { _ in
                completion()
            }
        } else {
            setHiddenTransform()
            completion()
        }
    }

    private func setHiddenTransform() {
        let yOffset: CGFloat

        switch swipeDirection {
        case .up:
            yOffset = -(frame.height + safeAreaInset.top)
        case .down:
            yOffset = frame.height + safeAreaInset.bottom
        default:
            yOffset = Constants.noVerticalTranslation
        }

        self.transform = CGAffineTransform(translationX: Constants.noHorizontalTranslation, y: yOffset)
    }
}
