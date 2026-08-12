//
//  EmbeddedBlockCoordinatorTests.swift
//  MindboxTests
//
//  Created by vailence on 12.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import SwiftUI
@testable import Mindbox

/// The coordinator writes the presentation reported by the container deferred — on the next turn
/// of the main queue. `dismantleUIView` silences the container's callbacks, but a write already
/// queued cannot be recalled — `detach()` cancels it: the subscription is re-checked at execution
/// time.
///
/// The suite is not marked `@available(iOS 13.0, *)` — the `@Suite`/`@Test` macros reject such
/// declarations. The test target builds for iOS 12, so each test opens SwiftUI availability for
/// itself with `guard #available`.
@Suite("Embedded block coordinator", .tags(.embeddedBlocks))
struct EmbeddedBlockCoordinatorTests {

    /// The write is deferred: the container may report a layer change in the middle of a body
    /// pass, and state must not change at that moment. It lands on the scheduler's turn — and is
    /// exactly what was reported.
    @Test("Update writes on the scheduled turn, not synchronously")
    func updateWritesOnScheduledTurn() {
        guard #available(iOS 13.0, *) else { return }

        var written = [EmbeddedBlockPresentation]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            presentation: Binding(get: { EmbeddedBlockPresentation(layer: .placeholder, height: 104) },
                                  set: { written.append($0) }),
            creationHeight: 104,
            onLoad: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        let content = EmbeddedBlockPresentation(layer: .content, height: 104)
        coordinator.update(content)

        #expect(written.isEmpty)

        scheduled.forEach { $0() }

        #expect(written == [content])
    }

    /// The dismantle race: the write is already queued, the view leaves the tree before it runs.
    /// After `detach()` the block must stay silent — the removed view's state is no longer its
    /// to write.
    @Test("Detach drops a write that was already scheduled")
    func detachDropsScheduledWrite() {
        guard #available(iOS 13.0, *) else { return }

        var written = [EmbeddedBlockPresentation]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            presentation: Binding(get: { EmbeddedBlockPresentation(layer: .placeholder, height: 104) },
                                  set: { written.append($0) }),
            creationHeight: 104,
            onLoad: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        coordinator.update(EmbeddedBlockPresentation(layer: .content, height: 104))
        coordinator.detach()

        scheduled.forEach { $0() }

        #expect(written.isEmpty)
    }
}
