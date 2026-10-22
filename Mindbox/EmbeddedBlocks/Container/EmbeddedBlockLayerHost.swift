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

    private let coveredContent: () -> UIView?

    private var attachedView: UIView?

    private var fadingOut: FadingLayer?

    private var cover: FadingLayer?

    private var hiddenContent: HiddenContent?

    private struct FadingLayer {
        let view: UIView
        let alpha: CGFloat
    }

    private struct HiddenContent {
        let view: UIView
        let alpha: CGFloat
        let isAccessibilityHidden: Bool
    }

    init(container: UIView,
         animation: EmbeddedBlockRevealAnimation = EmbeddedBlockRevealAnimation(),
         coveredContent: @escaping () -> UIView? = { nil }) {
        self.container = container
        self.animation = animation
        self.coveredContent = coveredContent
    }

    func show(_ view: UIView?, animated: Bool = false) {
        if let fadingOut {
            drop(fadingOut)
            self.fadingOut = nil
        }

        if let view, let content = coveredContent(), view !== content {
            cover(content, with: view)
            return
        }

        if cover != nil, let view, view === attachedView, view.superview === container {
            uncover(animated: animated)
            return
        }

        dropCover()

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

    private func cover(_ content: UIView, with placeholder: UIView) {
        if attachedView !== content || content.superview !== container {
            dropCover()
            attachedView?.removeFromSuperview()
            attachedView = content
            attach(content)
        }

        guard cover?.view !== placeholder || placeholder.superview !== container else { return }

        cover.map(drop)
        cover = FadingLayer(view: placeholder, alpha: placeholder.alpha)
        attach(placeholder)

        guard hiddenContent == nil else { return }

        hiddenContent = HiddenContent(view: content, alpha: content.alpha, isAccessibilityHidden: content.accessibilityElementsHidden)
        content.alpha = 0
        content.accessibilityElementsHidden = true
    }

    private func uncover(animated: Bool) {
        guard let cover else { return }

        self.cover = nil
        let content = hiddenContent
        hiddenContent = nil
        content.map { $0.view.accessibilityElementsHidden = $0.isAccessibilityHidden }

        guard animated else {
            drop(cover)
            content.map { $0.view.alpha = $0.alpha }
            return
        }

        fadingOut = cover
        animation.run(animation.duration, {
            content.map { $0.view.alpha = $0.alpha }
            cover.view.alpha = 0
        }, { [weak self] in
            guard let self else {
                Self.restoreAlpha(cover)
                return
            }

            guard self.fadingOut?.view === cover.view else { return }

            self.fadingOut = nil
            self.drop(cover)
        })
    }

    private func dropCover() {
        cover.map(drop)
        cover = nil
        hiddenContent.map {
            $0.view.alpha = $0.alpha
            $0.view.accessibilityElementsHidden = $0.isAccessibilityHidden
        }
        hiddenContent = nil
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
