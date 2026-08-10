//
//  EmbeddedBlockLayerHost.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

/// Держит в контейнере ровно одну вью, растянутую по его краям.
///
/// Слои блока — плейсхолдер, контент, экран ошибки — взаимоисключающие: показать новый значит снять
/// прежний. Показанная вью запоминается отдельно от свойств контейнера, потому что подменить её хост
/// может в любой момент, а снимать надо ту, что действительно висит, а не ту, что лежит в свойстве
/// сейчас.
final class EmbeddedBlockLayerHost {

    /// Владелец держит хост, поэтому обратная ссылка не считается — иначе контейнер не умрёт никогда.
    private unowned let container: UIView

    private var attachedView: UIView?

    init(container: UIView) {
        self.container = container
    }

    /// Показывает вью вместо той, что висит сейчас. `nil` — не показывать ничего.
    func show(_ view: UIView?) {
        guard attachedView !== view || view?.superview !== container else { return }

        attachedView?.removeFromSuperview()
        attachedView = view

        guard let view else { return }

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
