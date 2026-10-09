//
//  MindboxEmbeddedBlockView+InterfaceBuilder.swift
//  Mindbox
//
//  Created by vailence on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// A block created from a storyboard or xib.
///
/// In the Identity Inspector set the class to `MindboxEmbeddedBlockView` and the module to `Mindbox`:
/// without the module UIKit reports "Unknown class MindboxEmbeddedBlockView in Interface Builder
/// file" and silently puts a plain `UIView` in its place. In the Attributes Inspector fill the
/// inspectables: `placeSystemName` and `height` are required and mean what the initializer's
/// parameters mean; `loadingStrategyName`, `timeoutSeconds` and `animatesReveal` are optional.
/// Constrain the position and the width only, the way a block from code is laid out — the height
/// is the block's own, through `intrinsicContentSize`, and collapses to 0 when there is nothing to
/// show. The `delegate` is assigned from code: outlets cannot hold it.
///
/// The view attributes are the host's, as on any view from a nib: the block keeps the background
/// colour and the clipping given in the Attributes Inspector, where a block from code starts
/// transparent and clipping. The page inside is transparent, so a background left at the inspector's
/// default hides the host's background behind the block — set it to Clear Color to let it through.
///
/// The values are applied between `init(coder:)` and `awakeFromNib`, where the block builds itself
/// from them; from then on they are read-only, like for a block from code: the setters are not
/// public, and a key-value write after the build is ignored and reported.
extension MindboxEmbeddedBlockView {

    /// The height the block occupies when shown — the initializer's `height`. Required: left at 0,
    /// the block reserves no space and stays invisible whatever loads.
    @IBInspectable public private(set) var height: CGFloat {
        get { preferredHeight }
        set { applyInspectable("height") { preferredHeight = newValue } }
    }

    /// The initializer's `loadingStrategy` by name: `automatic`, `placeholder` or `hidden`, in any
    /// letter case. Empty means `automatic`; any other name is reported and means `automatic` too.
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

    /// The initializer's `timeout`, in seconds — not milliseconds like the Android attribute. Left
    /// at 0 — the inspector's default — it means the SDK default of 30, and that is what reads back.
    @IBInspectable public private(set) var timeoutSeconds: Double {
        get { setup.timeout }
        set { applyInspectable("timeoutSeconds") { setup.timeout = Self.timeout(fromInspectableSeconds: newValue) } }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        buildIfNeeded()
    }

    /// Builds a decoded block from the setup Interface Builder applied. Once: a block from code is
    /// built by its initializer and never passes here.
    func buildIfNeeded() {
        guard !isBuilt else { return }

        let place = setup.placeSystemName
        build(contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(placeSystemName: place),
              placeMemory: DI.injectOrFail(EmbeddedBlockPlaceRemembering.self),
              revealAnimation: EmbeddedBlockRevealAnimation(),
              makeWaitBudget: nil)
    }

    /// Setup given once the block is built is not obeyed: the dependencies were made for the
    /// values at hand, and a block that changes its place or look mid-life is not a feature.
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
