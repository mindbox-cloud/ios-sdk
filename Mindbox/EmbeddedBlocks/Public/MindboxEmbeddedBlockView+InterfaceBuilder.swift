//
//  MindboxEmbeddedBlockView+InterfaceBuilder.swift
//  Mindbox
//
//  Created by vailence on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Setting up a block in a storyboard or xib.
///
/// 1. In the Identity Inspector set Class to `MindboxEmbeddedBlockView` and Module to `Mindbox`.
///    Without the module, UIKit puts a plain `UIView` in its place.
/// 2. In the Attributes Inspector set ``placeSystemName`` and ``blockHeight`` (required), and
///    optionally ``loadingStrategyName``, ``timeoutSeconds`` and ``animatesReveal``.
/// 3. Constrain the position and width only: the block sets its own height.
/// 4. Assign ``delegate`` in code.
///
/// Unlike a block created in code, which is transparent and clips its content, a block from a nib
/// keeps the background color and clipping set in Interface Builder. The page inside is
/// transparent: set Background to Clear Color to let the host's background show through.
///
/// These values are read-only once the block is built, in code or from the nib: a later key-value
/// write is ignored and logged as an error.
extension MindboxEmbeddedBlockView {

    /// The initializer's `height`, in points. Required: 0 or less keeps the block invisible and is
    /// logged as an error.
    @IBInspectable public private(set) var blockHeight: CGFloat {
        get { preferredHeight }
        set { applyInspectable("blockHeight") { preferredHeight = newValue } }
    }

    /// The initializer's `loadingStrategy` by name: `automatic`, `placeholder` or `hidden`, in any
    /// letter case. Empty means `automatic`; any other name is logged as an error and means
    /// `automatic` too.
    @IBInspectable public private(set) var loadingStrategyName: String {
        get { String(describing: loadingStrategy) }
        set {
            applyInspectable("loadingStrategyName") {
                let strategy = Self.loadingStrategy(named: newValue)
                setup.loadingStrategy = strategy ?? .automatic
                setup.unknownLoadingStrategyName = strategy == nil ? newValue : nil
            }
        }
    }

    /// The initializer's `timeout`, in seconds. Unset, 0 or less means 30 and reads back as 30.
    @IBInspectable public private(set) var timeoutSeconds: Double {
        get { setup.timeout }
        set { applyInspectable("timeoutSeconds") { setup.timeout = Self.timeout(fromInspectableSeconds: newValue) } }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        buildIfNeeded()
    }

    func buildIfNeeded() {
        guard !isBuilt else { return }

        build(contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(placeSystemName: placeKey),
              placeMemory: DI.injectOrFail(EmbeddedBlockPlaceRemembering.self),
              revealAnimation: EmbeddedBlockRevealAnimation(),
              makeWaitBudget: nil,
              afterMainPass: Self.onTheNextMainPass)
    }

    func applyInspectable(_ name: String, _ change: () -> Void) {
        guard !isBuilt else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given `\(name)` after it was built: ignored. Set it at creation or in Interface Builder.",
                          level: .error,
                          category: .embeddedBlocks)
            return
        }

        change()
    }
}
