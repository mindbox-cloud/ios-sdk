//  SnackbarView.swift
//  Mindbox
//
//  Created by vailence on 15.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

class SnackbarView: UIView {
    
    public var swipeDirection: UISwipeGestureRecognizer.Direction = .down

    private let onClose: () -> Void
    private let animationTime: TimeInterval
    
    enum Constants {
        static let defaultAnimationTime: TimeInterval = 0.3
        static let swipeThresholdFraction: CGFloat = 0.5
    }

    init(onClose: @escaping () -> Void,
         animationTime: TimeInterval = Constants.defaultAnimationTime) {
        self.onClose = onClose
        self.animationTime = animationTime
        super.init(frame: .zero)

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
        if (swipeDirection == .up && translation.y < 0) || (swipeDirection == .down && translation.y > 0) {
            self.transform = CGAffineTransform(translationX: 0, y: translation.y)
            self.alpha = max(0, 1 - abs(translation.y) / self.frame.height)
        }
    }

    private func finalizeGesture(translation: CGPoint) {
        if ((swipeDirection == .up && translation.y < 0) || (swipeDirection == .down && translation.y > 0)) &&
            abs(translation.y) > self.frame.height * Constants.swipeThresholdFraction {
            UIView.animate(withDuration: animationTime, animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(translationX: 0, y: self.swipeDirection == .up ? -self.frame.height : self.frame.height)
            }) { [weak self] _ in
                self?.onClose()
            }
        } else {
            UIView.animate(withDuration: animationTime) {
                self.alpha = 1
                self.transform = .identity
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


