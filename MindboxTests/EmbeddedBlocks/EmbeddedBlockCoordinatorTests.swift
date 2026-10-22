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

@Suite("Embedded block coordinator", .tags(.embeddedBlocks))
struct EmbeddedBlockCoordinatorTests {

    @Test("Update writes on the scheduled turn, not synchronously")
    func updateWritesOnScheduledTurn() {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance?]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .placeholder }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        coordinator.update(.content, animated: false)

        #expect(written.isEmpty)

        scheduled.forEach { $0() }

        #expect(written == [.content])
    }

    @Test("Detach drops a write that was already scheduled")
    func detachDropsScheduledWrite() {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance?]()
        var scheduled = [() -> Void]()
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .placeholder }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) }
        )

        coordinator.update(.content, animated: false)
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

    @Test("A block holding a collapse that SwiftUI dismantles tells the host on the scheduled turn, not inside the update",
          arguments: [false, true])
    @MainActor
    func dismantledBlockTellsTheHostTheHeldCollapseOnTheScheduledTurn(placeCannotBeChecked: Bool) async throws {
        guard #available(iOS 13.0, *) else { return }

        var heard: [String] = []
        var scheduled = [() -> Void]()
        var coordinator: EmbeddedBlockRepresentable.Coordinator? = EmbeddedBlockRepresentable.Coordinator(
            appearance: .constant(.placeholder),
            onLoad: { heard.append("load") },
            onEmpty: { heard.append("empty") },
            onFail: { heard.append("fail:\($0.rawValue)") },
            schedule: { scheduled.append($0) }
        )
        let bed = EmbeddedBlockTestBed()
        let view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                            height: 104,
                                            contentProvider: bed.provider,
                                            placeMemory: EmbeddedBlockPlaceMemoryMock(),
                                            loadingStrategy: .placeholder)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.delegate = coordinator
        window.addSubview(view)
        bed.page?.reportRendered(1)
        bed.resolver.resolution = placeCannotBeChecked ? .targetingUnavailable : .empty
        bed.announceNewConfig()
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(heard == ["load"])

        try EmbeddedBlockRepresentable.dismantleUIView(view, coordinator: #require(coordinator))

        #expect(heard == ["load"])
        coordinator = nil
        scheduled.forEach { $0() }
        #expect(heard == ["load", "empty"])
    }

    @Test("A look the container calls the reveal is written under the animation")
    func revealIsWrittenUnderTheAnimation() {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance?]()
        var scheduled = [() -> Void]()
        var animatedWrites = 0
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { .collapsed }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) },
            animate: { changes in
                animatedWrites += 1
                changes()
            }
        )

        coordinator.update(.content, animated: true)
        scheduled.forEach { $0() }

        #expect(written == [.content])
        #expect(animatedWrites == 1)
    }

    @Test("A look the container does not call the reveal lands at once, content included",
          arguments: [MindboxEmbeddedBlockAppearance.content, .placeholder, .collapsed, .error])
    func otherLooksLandAtOnce(newAppearance: MindboxEmbeddedBlockAppearance) {
        guard #available(iOS 13.0, *) else { return }

        var written = [MindboxEmbeddedBlockAppearance?]()
        var scheduled = [() -> Void]()
        var animatedWrites = 0
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { nil }, set: { written.append($0) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) },
            animate: { changes in
                animatedWrites += 1
                changes()
            }
        )

        coordinator.update(newAppearance, animated: false)
        scheduled.forEach { $0() }

        #expect(written == [newAppearance])
        #expect(animatedWrites == 0)
    }

    @Test("The observer the representable installs hands over the container's verdict with each look")
    @MainActor
    func installedObserverHandsOverTheContainersVerdict() {
        guard #available(iOS 13.0, *) else { return }

        var current: MindboxEmbeddedBlockAppearance?
        var written = [(MindboxEmbeddedBlockAppearance?, Bool)]()
        var scheduled = [() -> Void]()
        var isAnimating = false
        let coordinator = EmbeddedBlockRepresentable.Coordinator(
            appearance: Binding(get: { current }, set: { current = $0; written.append(($0, isAnimating)) }),
            onLoad: nil,
            onEmpty: nil,
            onFail: nil,
            schedule: { scheduled.append($0) },
            animate: { changes in
                isAnimating = true
                changes()
                isAnimating = false
            }
        )
        let bed = EmbeddedBlockTestBed()
        let reveal = EmbeddedBlockRevealAnimationSpy()
        let view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                            height: 104,
                                            contentProvider: bed.provider,
                                            placeMemory: EmbeddedBlockPlaceMemoryMock(),
                                            loadingStrategy: .hidden,
                                            revealAnimation: reveal.animation)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        EmbeddedBlockRepresentable.observe(view, with: coordinator)
        window.addSubview(view)
        bed.page?.reportRendered(1)
        scheduled.forEach { $0() }

        #expect(written.first.map { $0.0 == .collapsed && !$0.1 } == true)
        #expect(written.last.map { $0.0 == .content && $0.1 } == true)
    }
}
