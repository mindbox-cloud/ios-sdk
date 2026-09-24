//
//  EmbeddedBlockCoordinatorTests.swift
//  MindboxTests
//
//  Created by vailence on 12.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import SwiftUI
@_spi(Internal) @testable import Mindbox

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

        var written = [MindboxEmbeddedBlockAppearance]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .placeholder }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        coordinator.update(.content)

        #expect(written.isEmpty)

        scheduled.forEach { $0() }

        #expect(written == [.content])
    }

    /// The dismantle race: the write is already queued, the view leaves the tree before it runs.
    /// After `detach()` the block must stay silent — the removed view's state is no longer its
    /// to write.
    @Test("Detach drops a write that was already scheduled")
    func detachDropsScheduledWrite() {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .placeholder }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        coordinator.update(.content)
        coordinator.detach()

        scheduled.forEach { $0() }

        #expect(written.isEmpty)
    }

    @Test("onLoad, onEmpty and onFail(reason) are forwarded as they arrive")
    @MainActor
    func outcomeClosuresAreForwarded() {
        guard #available(iOS 13.0, *) else { return }

        var heard: [String] = []
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: .constant(.placeholder),
            onLoad: { heard.append("load") },
            onEmpty: { heard.append("empty") },
            onFail: { heard.append("fail:\($0.rawValue)") },
            schedule: { _ in }
        )
        let view = MindboxEmbeddedBlockView(placeSystemName: "stories",
                                            height: 104,
                                            contentProvider: EmbeddedBlockTestBed().provider,
                                            placeMemory: EmbeddedBlockPlaceMemoryMock(),
                                            loadingStrategy: .placeholder)

        coordinator.mindboxEmbeddedBlockViewDidLoad(view)
        coordinator.mindboxEmbeddedBlockViewDidBecomeEmpty(view)
        coordinator.mindboxEmbeddedBlockViewDidFail(view, reason: .networkError)

        #expect(heard == ["load", "empty", "fail:networkError"])
    }

    /// The wrapper owns the block's frame: the growth of a block that waited hidden — and the swap of
    /// its own placeholder for the content — is its animation to run, on the reveal and only there.
    @Test("Content is written under the reveal animation")
    func contentIsWrittenUnderTheAnimation() {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance]()
        var scheduled = [() -> Void]()
        var animatedWrites = 0
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .collapsed }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            animatesReveal: true,
            schedule: { scheduled.append($0) },
            animateReveal: { changes in
                animatedWrites += 1
                changes()
            }
        )

        coordinator.update(.content)
        scheduled.forEach { $0() }

        #expect(written == [.content])
        #expect(animatedWrites == 1)
    }

    @Test("A collapse and an error screen land at once", arguments: [MindboxEmbeddedBlockAppearance.collapsed, .error])
    func collapseAndErrorAreNotAnimated(newAppearance: MindboxEmbeddedBlockAppearance) {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance]()
        var scheduled = [() -> Void]()
        var animatedWrites = 0
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .placeholder }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            animatesReveal: true,
            schedule: { scheduled.append($0) },
            animateReveal: { changes in
                animatedWrites += 1
                changes()
            }
        )

        coordinator.update(newAppearance)
        scheduled.forEach { $0() }

        #expect(written == [newAppearance])
        #expect(animatedWrites == 0)
    }

    @Test("With the animation turned off the content lands at once too")
    func contentLandsAtOnceWithTheAnimationOff() {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance]()
        var scheduled = [() -> Void]()
        var animatedWrites = 0
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .collapsed }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            animatesReveal: false,
            schedule: { scheduled.append($0) },
            animateReveal: { changes in
                animatedWrites += 1
                changes()
            }
        )

        coordinator.update(.content)
        scheduled.forEach { $0() }

        #expect(written == [.content])
        #expect(animatedWrites == 0)
    }
}
