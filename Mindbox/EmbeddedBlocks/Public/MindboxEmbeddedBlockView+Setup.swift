//
//  MindboxEmbeddedBlockView+Setup.swift
//  Mindbox
//
//  Created by vailence on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

/// What a block is given at creation, whichever way it is created: by the initializer, or by
/// Interface Builder between `init(coder:)` and `awakeFromNib`.
struct EmbeddedBlockSetup {

    var placeSystemName = ""

    var loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic

    /// A strategy name Interface Builder gave that matched nothing. Reported at the build, when the
    /// place name is known: the attributes arrive in the order the xib lists them.
    var unknownLoadingStrategyName: String?

    /// The timeout in effect, in seconds: a missing or broken one is already the SDK default.
    var timeout = TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)

    var animatesReveal = true
}

/// Sanitizing and parsing the setup, shared by both ways of creating a block.
extension MindboxEmbeddedBlockView {

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

    /// The inspector cannot express "no value": 0 — and anything below it — stands for the default.
    static func timeout(fromInspectableSeconds value: Double) -> TimeInterval {
        value > 0 ? value : TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)
    }

    /// `automatic`, `placeholder` or `hidden` in any letter case; empty is `automatic`; anything
    /// else is `nil`, for the caller to report once it knows which block it is about.
    static func loadingStrategy(named name: String) -> MindboxEmbeddedBlockLoadingStrategy? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "automatic":
            return .automatic
        case "placeholder":
            return .placeholder
        case "hidden":
            return .hidden
        default:
            return nil
        }
    }

    /// Integration errors in the setup, reported once at the build. None of them stops the block:
    /// it runs its whole cycle and the host sees the outcome through the delegate.
    func warnAboutSetup() {
        // An empty name addresses no place, and the name is never normalized: whatever the host
        // passed is what the config is asked for.
        if placeSystemName.isEmpty {
            Logger.common(message: "[EmbeddedBlock] A block was created without a place system name: it has nothing to resolve and stays invisible.",
                          level: .error,
                          category: .embeddedBlocks)
        }

        // Zero height is not a collapse: the block runs its whole cycle, it is simply never visible.
        if preferredHeight <= 0 {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was created with height \(preferredHeight): it reserves no space and stays invisible whatever loads. Pass the height it should occupy.",
                          level: .error,
                          category: .embeddedBlocks)
        }

        if let name = setup.unknownLoadingStrategyName {
            Logger.common(message: "[EmbeddedBlock] Block '\(placeSystemName)' was given loading strategy '\(name)' in Interface Builder: unknown, using automatic. The names are automatic, placeholder and hidden.",
                          level: .error,
                          category: .embeddedBlocks)
        }
    }
}
