//
//  MindboxEmbeddedBlockAppearance.swift
//  Mindbox
//
//  Created by vailence on 18.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// How the block occupies its place right now — the contract between the container and a wrapper
/// that lays the block out itself.
///
/// A UIKit host needs none of this: the container holds the right view inside and declares its height
/// through `intrinsicContentSize`, both on its own. A wrapper cannot rely on either. SwiftUI assigns
/// the height itself, and the host's placeholder and error screen are SwiftUI views the wrapper has to
/// draw — one handed to the container as a `UIView` falls out of the SwiftUI tree and loses its
/// environment. A Flutter platform view has it worse still: its size comes from the Dart side, so
/// nothing about the container's own layout reaches it at all.
///
/// So a wrapper is told what to show, not what happened. Everything behind the decision — the four
/// content states, the rule that an empty place shows no error view, the one that a collapsed place is
/// not won back by a retry — stays inside the container, and the same answer serves every wrapper.
///
/// Deliberately not part of the public API: available only through `@_spi(Internal) import Mindbox`.
/// The host observes outcomes through `MindboxEmbeddedBlockViewDelegate` and nothing else.
@_spi(Internal)
public enum MindboxEmbeddedBlockAppearance {

    /// The content is loading. A wrapper with a placeholder of its own draws it; without one the
    /// container's shimmer is already on screen.
    case placeholder

    /// The block content is shown — the wrapper draws nothing over it.
    case content

    /// The block failed and the host opted into showing it: the wrapper draws its error screen.
    /// Never appears for an empty place.
    case error

    /// The block occupies no space: a failure without an error screen, or an empty place. The wrapper
    /// gives the space back to the layout.
    case collapsed
}
