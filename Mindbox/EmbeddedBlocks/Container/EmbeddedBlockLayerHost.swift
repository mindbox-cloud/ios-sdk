//
//  EmbeddedBlockLayerHost.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// Holds exactly one view in the container, stretched to its edges.
///
/// The block's layers — placeholder, content, error screen — are mutually exclusive: showing a new
/// one means removing the previous one. The shown view is remembered separately from the
/// container's properties, because the host can swap it at any moment, and the view to remove is
/// the one that is actually attached, not the one sitting in a property right now.
final class EmbeddedBlockLayerHost {

    /// The owner holds the host, so the back reference must not count — or the container never dies.
    private unowned let container: UIView

    private var attachedView: UIView?

    init(container: UIView) {
        self.container = container
    }

    /// Shows the view in place of the one attached now. `nil` — show nothing.
    func show(_ view: UIView?) {
        // "Show nothing" is simply removing the current view: there is nothing to compare here, and
        // the shared condition below, made to cover nil, would read as something it is not.
        guard let view else {
            attachedView?.removeFromSuperview()
            attachedView = nil
            return
        }

        // The same view, and it really is attached to us — no reason to rebuild its constraints.
        guard attachedView !== view || view.superview !== container else { return }

        attachedView?.removeFromSuperview()
        attachedView = view

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
