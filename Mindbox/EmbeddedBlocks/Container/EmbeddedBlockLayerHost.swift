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

    private var attachedView: UIView?

    init(container: UIView) {
        self.container = container
    }

    /// Shows the view in place of the one attached now. `nil` — show nothing.
    func show(_ view: UIView?) {
        guard let view else {
            attachedView?.removeFromSuperview()
            attachedView = nil
            return
        }

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
