//
//  MindboxEmbeddedBlockView+Setup.swift
//  Mindbox
//
//  Created by vailence on 09.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

struct EmbeddedBlockSetup {

    var placeSystemName = ""

    var loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .automatic

    var unknownLoadingStrategyName: String?

    var timeout = TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)

    var animatesReveal = true
}

extension MindboxEmbeddedBlockView {

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

    static func timeout(fromInspectableSeconds value: Double) -> TimeInterval {
        value > 0 ? value : TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)
    }

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

    static func normalizedPlaceSystemName(_ given: String) -> String {
        given.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func placeKey(_ placeSystemName: String) -> String {
        EmbeddedFormVariant.placeKey(placeSystemName)
    }

    static func onTheNextMainPass(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    static func initialAppearance(for strategy: MindboxEmbeddedBlockLoadingStrategy,
                                  hasShownContentBefore: Bool) -> MindboxEmbeddedBlockAppearance {
        switch strategy {
        case .placeholder:
            return .placeholder
        case .hidden:
            return .collapsed
        case .automatic:
            return hasShownContentBefore ? .placeholder : .collapsed
        }
    }

    func warnAboutSetup() {
        if placeSystemName.isEmpty {
            Logger.common(message: "[EmbeddedBlock] A block was created without a place system name: it has nothing to resolve and stays invisible.",
                          level: .error,
                          category: .embeddedBlocks)
        }

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
