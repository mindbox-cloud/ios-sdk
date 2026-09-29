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
    /// next `show` comes first.
    private var fadingOutView: UIView?

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
        if let fadingOutView {
            drop(fadingOutView)
            self.fadingOutView = nil
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

        fadingOutView = previous
        view.alpha = 0
        animation.run(animation.duration, {
            view.alpha = 1
            previous?.alpha = 0
        }, { [weak self] in
            guard let self, self.fadingOutView === previous else { return }

            self.fadingOutView = nil
            previous.map(self.drop)
        })
    }

    /// The faded-out layer is shown again on the next load — the shimmer is one instance for the
    /// block's whole life — so it leaves with its alpha back at 1.
    private func drop(_ view: UIView) {
        view.removeFromSuperview()
        view.alpha = 1
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
