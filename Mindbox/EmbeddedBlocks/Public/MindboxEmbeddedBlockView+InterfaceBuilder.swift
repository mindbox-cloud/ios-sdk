//
//  MindboxEmbeddedBlockView+InterfaceBuilder.swift
//  Mindbox
//
//  Created by vailence on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// What a block is given at creation, whichever way it is created.
struct EmbeddedBlockSetup {

    var placeSystemName = ""

    var loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic

    /// `nil` is the SDK default.
    var timeout: TimeInterval?

    var animatesReveal = true
}

/// A block created from a storyboard or xib.
///
/// Set the class of a view to `MindboxEmbeddedBlockView` and fill the inspectables in the Attributes
/// Inspector: `placeSystemName` and `height` are required and mean what the initializer's parameters
/// mean; `loadingStrategyName`, `timeout` and `animatesReveal` are optional. Constrain the position
/// and the width only, the way a block from code is laid out — the height is the block's own, through
/// `intrinsicContentSize`, and collapses to 0 when there is nothing to show. The `delegate` is
/// assigned from code: outlets cannot hold it.
///
/// The values are applied between `init(coder:)` and `awakeFromNib`, where the block builds itself
/// from them; from then on they are read-only, like for a block from code.
extension MindboxEmbeddedBlockView {

    /// The height the block occupies when shown — the initializer's `height`. Required: left at 0,
    /// the block reserves no space and stays invisible whatever loads.
    @IBInspectable public var height: CGFloat {
        get { preferredHeight }
        set {
            guard !isBuilt else {
                Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given `height` after it was built: ignored. Set it at creation or in Interface Builder.",
                              level: .error,
                              category: .embeddedBlocks)
                return
            }

            preferredHeight = newValue
        }
    }

    /// The initializer's `loadingStrategy` by name: `automatic`, `placeholder` or `hidden`, in any
    /// letter case. Empty means `automatic`; any other name is reported and means `automatic` too.
    @IBInspectable public var loadingStrategyName: String {
        get { String(describing: loadingStrategy) }
        set {
            updateSetup("loadingStrategyName") { setup in
                setup.loadingStrategy = Self.loadingStrategy(named: newValue, placeSystemName: setup.placeSystemName)
            }
        }
    }

    /// The initializer's `timeout`, in seconds. Left at 0 — the inspector's default — it means
    /// the SDK default of 30.
    @IBInspectable public var timeout: Double {
        get { setup.timeout ?? 0 }
        set { updateSetup("timeout") { $0.timeout = Self.timeout(fromInspectable: newValue) } }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        buildFromInterfaceBuilderIfNeeded()
    }

    /// Builds a nib-loaded block from the setup Interface Builder applied. Once: a block from code is
    /// built by its initializer and never passes here.
    private func buildFromInterfaceBuilderIfNeeded() {
        guard !isBuilt else { return }

        let place = setup.placeSystemName
        build(contentProvider: DI.injectOrFail(EmbeddedBlockContentProviderMaking.self).makeProvider(placeSystemName: place),
              placeMemory: DI.injectOrFail(EmbeddedBlockPlaceRemembering.self),
              revealAnimation: EmbeddedBlockRevealAnimation(),
              makeWaitBudget: nil)
    }

    /// Setup given once the block is built is not obeyed: the dependencies were made for the
    /// values at hand, and a block that changes its place or look mid-life is not a feature.
    func updateSetup(_ name: String, _ change: (inout EmbeddedBlockSetup) -> Void) {
        guard !isBuilt else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given `\(name)` after it was built: ignored. Set it at creation or in Interface Builder.",
                          level: .error,
                          category: .embeddedBlocks)
            return
        }

        change(&setup)
    }

    /// The inspector cannot express "no value": 0 — and anything below it — stands for the default.
    static func timeout(fromInspectable value: Double) -> TimeInterval? {
        value > 0 ? value : nil
    }

    // MARK: - Setup sanitizing

    /// A non-positive timeout would collapse every block before the config had a chance, so it is
    /// reported and replaced with the default rather than obeyed.
    static func sanitizedTimeout(_ timeout: TimeInterval?, placeSystemName: String) -> TimeInterval {
        guard let timeout else {
            return TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)
        }

        guard timeout > 0 else {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given timeout \(timeout): it must be positive, using the default \(Constants.EmbeddedBlock.answerTimeoutSeconds) s",
                          level: .error, category: .embeddedBlocks)
            return TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)
        }

        return timeout
    }

    static func loadingStrategy(named name: String, placeSystemName: String) -> MindboxEmbeddedBlockLoadingStrategy {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "automatic":
            return .automatic
        case "placeholder":
            return .placeholder
        case "hidden":
            return .hidden
        default:
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given loading strategy '\(name)': unknown, using automatic. The names are automatic, placeholder and hidden.",
                          level: .error,
                          category: .embeddedBlocks)
            return .automatic
        }
    }
}
