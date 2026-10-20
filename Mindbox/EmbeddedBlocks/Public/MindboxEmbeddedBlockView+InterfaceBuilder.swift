//
//  MindboxEmbeddedBlockView+InterfaceBuilder.swift
//  Mindbox
//
//  Created by vailence on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// Interface Builder setup: set Class to `MindboxEmbeddedBlockView` and Module to `Mindbox`, set
/// ``placeSystemName`` and ``blockHeight`` in the Attributes Inspector, constrain the position and width
/// only, and assign ``delegate`` in code.
extension MindboxEmbeddedBlockView {

    /// The block's height, in points, while it is not collapsed. Required.
    @IBInspectable public private(set) var blockHeight: CGFloat {
        get { preferredHeight }
        set { applyInspectable("blockHeight") { preferredHeight = newValue } }
    }

    /// The loading strategy by name: `automatic` (the default), `placeholder` or `hidden`.
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

    /// How long, in seconds, the block waits for the SDK to choose its content; unset means 30.
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
