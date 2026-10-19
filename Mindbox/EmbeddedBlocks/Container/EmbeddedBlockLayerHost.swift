//
//  EmbeddedBlockLayerHost.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

final class EmbeddedBlockLayerHost {

    private unowned let container: UIView

    private let animation: EmbeddedBlockRevealAnimation

    private var attachedView: UIView?

    private var fadingOut: FadingLayer?

    private struct FadingLayer {
        let view: UIView
        let alpha: CGFloat
    }

    init(container: UIView, animation: EmbeddedBlockRevealAnimation = EmbeddedBlockRevealAnimation()) {
        self.container = container
        self.animation = animation
    }

    func show(_ view: UIView?, animated: Bool = false) {
        if let fadingOut {
            drop(fadingOut)
            self.fadingOut = nil
        }

        guard let view else {
            attachedView?.removeFromSuperview()
            attachedView = nil
            return
        }

        guard attachedView !== view || view.superview !== container else { return }

        let previous = attachedView !== view ? attachedView : nil
        attachedView = view
        attach(view)

        guard animated else {
            previous?.removeFromSuperview()
            return
        }

        let fading = previous.map { FadingLayer(view: $0, alpha: $0.alpha) }
        fadingOut = fading
        view.alpha = 0
        animation.run(animation.duration, {
            view.alpha = 1
            fading?.view.alpha = 0
        }, { [weak self] in
            guard let self else {
                fading.map(Self.restoreAlpha)
                return
            }

            guard self.fadingOut?.view === fading?.view else { return }

            self.fadingOut = nil
            fading.map(self.drop)
        })
    }

    private func drop(_ layer: FadingLayer) {
        layer.view.removeFromSuperview()
        Self.restoreAlpha(layer)
    }

    private static func restoreAlpha(_ layer: FadingLayer) {
        layer.view.alpha = layer.alpha
    }

    private func attach(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
