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
        if #available(iOS 11.0, *) {
            return (
                window?.safeAreaInsets.top ?? 0,
                window?.safeAreaInsets.bottom ?? 0
            )
        } else {
            return (0, 0)
        }
    }
    
    private enum Constants {
        static let defaultAnimationTime: TimeInterval = 0.3
        static let swipeThresholdFraction: CGFloat = 0.5
    }

    // MARK: Init

    init(onClose: @escaping () -> Void,
         animationTime: TimeInterval = Constants.defaultAnimationTime) {
        self.onClose = onClose
        self.animationTime = animationTime
        super.init(frame: .zero)
        Logger.common(message: "SnackbarView inited.")
        setupPanGesture()
    }
    
    required init?(coder: NSCoder) {
        Logger.common(message: "SnackbarView init(coder:) has not been implemented.")
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
        if (swipeDirection == .up && translation.y < 0) || (swipeDirection == .down && translation.y > 0) {
            self.transform = CGAffineTransform(translationX: 0, y: translation.y)
        }
    }

    private func finalizeGesture(translation: CGPoint) {
        let threshold = frame.height * Constants.swipeThresholdFraction +
        (swipeDirection == .up ? safeAreaInset.top : safeAreaInset.bottom)
        if ((swipeDirection == .up && translation.y < 0) || (swipeDirection == .down && translation.y > 0)) &&
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
            yOffset = -(frame.height + safeAreaInset.top)
        case .down:
            yOffset = frame.height + safeAreaInset.bottom
        default:
            yOffset = 0
        }
        
        self.transform = CGAffineTransform(translationX: 0, y: yOffset)
    }
}
