//
//  MindboxEmbeddedBlockLoadingStrategy.swift
//  Mindbox
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// What the block shows until the SDK has decided what goes into it — given at creation.
///
/// Every place marked up in the app waits for the SDK on every launch, and a place with no campaign
/// behind it would flash a placeholder and collapse each time. The strategy decides whether the block
/// takes its space before the answer, and the SDK remembers per place whether content was ever shown
/// there, so the layout does not jump where content is expected and does not flash where it is not.
///
/// The same three values exist on every platform; `automatic` is the default everywhere.
public enum MindboxEmbeddedBlockLoadingStrategy: Sendable {

    /// Hidden until the place has shown content once on this device; a placeholder from then on.
    ///
    /// The memory is per `placeSystemName` and survives a restart. It is dropped when the place
    /// answers with nothing to show — the campaign was switched off, the targeting did not match, the
    /// page rendered nothing — so the next launch starts hidden again. A failure keeps the memory:
    /// that is "could not", not "nothing here".
    case automatic

    /// Always a placeholder until the answer: the SDK shimmer or the host's `placeholderView`.
    case placeholder

    /// Always hidden until the content is shown: zero height, no placeholder, and no `errorView` on a
    /// failure — a block that never took its space does not take it for an error screen either.
    /// The outcome still arrives through `onFail`.
    case hidden
}
