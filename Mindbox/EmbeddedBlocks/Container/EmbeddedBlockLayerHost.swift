//
//  EmbeddedBlockLayerHost.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// Holds exactly one view in the container, stretched to its edges.
final class EmbeddedBlockLayerHost {

    /// The owner holds the host, so the back reference must not count — or the container never dies.
    private unowned let container: UIView

    private let animation: EmbeddedBlockRevealAnimation

    private var attachedView: UIView?

    /// The view still on screen under the one fading in over it — until the fade ends, or until the
    /// next `show` comes first — with the alpha it had before the fade, to leave with.
    private var fadingOut: FadingLayer?

    private struct FadingLayer {
        let view: UIView
        let alpha: CGFloat
    }

    init(container: UIView, animation: EmbeddedBlockRevealAnimation = EmbeddedBlockRevealAnimation()) {
        self.container = container
        self.animation = animation
    }

    /// Shows the view in place of the one attached now. `nil` — show nothing. `animated` cross-fades:
    /// the view fades in while the previous one fades out under it, and leaves when the fade ends.
    /// The page is transparent, so a previous layer left opaque would show through its empty parts
    /// for the whole fade and then vanish in one frame.
    func show(_ view: UIView?, animated: Bool = false) {
        // A fade still running is over: what it was replacing goes now.
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

        // The same view detached from outside is simply put back: there is nothing to replace.
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
            // The host may be gone before the fade ends — the block with it — and the layer it was
            // fading out must still be left as it was found: a host's own placeholder is the host's
            // to reuse.
            guard let self else {
                fading.map(Self.restoreAlpha)
                return
            }

            guard self.fadingOut?.view === fading?.view else { return }

            self.fadingOut = nil
            fading.map(self.drop)
        })
    }

    /// The faded-out layer is shown again on the next load — the shimmer is one instance for the
    /// block's whole life, a host's placeholder is the host's — so it leaves with the alpha it came with.
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
