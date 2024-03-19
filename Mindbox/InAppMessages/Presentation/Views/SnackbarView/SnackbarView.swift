//  SnackbarView.swift
//  Mindbox
//
//  Created by vailence on 15.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

class SnackbarView: UIView {

    public var swipeDirection: UISwipeGestureRecognizer.Direction = .down

    private let onClose: () -> Void
    private let animationTime: TimeInterval
    
    private var safeAreaBottomInset: CGFloat {
        if #available(iOS 11.0, *) {
            return window?.safeAreaInsets.bottom ?? Constants.defaultSafeAreaBottomInset
        } else {
            return Constants.defaultSafeAreaBottomInset
        }
    }
    private var safeAreaTopInset: CGFloat {
        if #available(iOS 11.0, *) {
            return window?.safeAreaInsets.top ?? Constants.defaultSafeAreaTopInset
        } else {
            return Constants.defaultSafeAreaTopInset
        }
    }

    private enum Constants {
        static let defaultAnimationTime: TimeInterval = 0.3
        static let swipeThresholdFraction: CGFloat = 0.5
        static let defaultSafeAreaBottomInset: CGFloat = .zero
        static let defaultSafeAreaTopInset: CGFloat = .zero
        static let noTranslationX: CGFloat = .zero
        static let noTranslationY: CGFloat = .zero
    }

    init(onClose: @escaping () -> Void,
         animationTime: TimeInterval = Constants.defaultAnimationTime) {
        self.onClose = onClose
        self.animationTime = animationTime
        super.init(frame: .zero)
        Logger.common(message: "SnackbarView inited.")
        setupPanGesture()
    }
 
    private func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        self.addGestureRecognizer(panGesture)
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
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
        if (swipeDirection == .up && translation.y < .zero) || 
            (swipeDirection == .down && translation.y > .zero) {
            self.transform = CGAffineTransform(translationX: Constants.noTranslationX, y: translation.y)
        }
    }

    private func finalizeGesture(translation: CGPoint) {
        let threshold = frame.height * Constants.swipeThresholdFraction +
        (swipeDirection == .up ? safeAreaTopInset : safeAreaBottomInset)
        if ((swipeDirection == .up && translation.y < .zero) || 
            (swipeDirection == .down && translation.y > .zero)) &&
            abs(translation.y) > threshold {
            animateHide(completion: onClose, animated: true)
            
        } else {
            UIView.animate(withDuration: animationTime) {
                self.transform = .identity
            }
        }
    }

    private func animateHide(completion: @escaping () -> Void, animated: Bool) {
        if animated {
            UIView.animate(withDuration: animationTime, animations: {
                self.setHiddenTransform()
            }) { _ in
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
                yOffset = -(frame.height + safeAreaTopInset)
            case .down:
                yOffset = frame.height + safeAreaBottomInset
            default:
                yOffset = Constants.noTranslationY
        }
        self.transform = CGAffineTransform(translationX: Constants.noTranslationX, y: yOffset)
    }

    public func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        animateHide(completion: {
            self.onClose()
            completion?()
        }, animated: animated)
    }

    required init?(coder: NSCoder) {
        Logger.common(message: "SnackbarView init(coder:) has not been implemented.")
        fatalError("init(coder:) has not been implemented")
    }
}
