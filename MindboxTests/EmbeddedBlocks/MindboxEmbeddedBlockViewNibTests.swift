//
//  MindboxEmbeddedBlockViewNibTests.swift
//  MindboxTests
//
//  Created by vailence on 08.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@_spi(Internal) @testable import Mindbox

/// A block created from Interface Builder: the real nib loader runs `init?(coder:)`, applies the
/// inspectables the way the Attributes Inspector stores them and calls `awakeFromNib`.
@Suite("MindboxEmbeddedBlockView from a nib", .tags(.embeddedBlocks))
@MainActor
struct MindboxEmbeddedBlockViewNibTests {

    // MARK: - Inspectables

    @Test("A block from a nib takes its place, height, strategy and animation from the inspectables")
    func nibBlockReadsItsInspectables() throws {
        let nib = NibFixture()

        let view = try nib.loadConfiguredBlock()

        // The name is normalized at the boundary, the way the code path normalizes it.
        #expect(view.placeSystemName == "Stories")
        #expect(view.loadingStrategy == .placeholder)
        #expect(view.animatesReveal == false)
        #expect(view.intrinsicContentSize.height == 96)
    }

    @Test("Inspectables left untouched in Interface Builder mean the code path's defaults")
    func nibBlockFallsBackToDefaults() throws {
        let nib = NibFixture()

        let view = try nib.loadDefaultBlock()

        #expect(view.placeSystemName == "promo")
        #expect(view.loadingStrategy == .automatic)
        #expect(view.animatesReveal == true)
    }

    @Test("A block from a nib asks the SDK for the place it was given")
    func nibBlockAsksTheSdkForItsPlace() throws {
        let nib = NibFixture()

        _ = try nib.loadConfiguredBlock()

        #expect(nib.factory.requestedPlaces == ["Stories", "promo"])
        #expect(nib.memory.askedPlaces == ["Stories", "promo"])
    }

    @Test("The strategy name is matched by its case-insensitive spelling, an unknown name means automatic",
          arguments: [("automatic", MindboxEmbeddedBlockLoadingStrategy.automatic),
                      ("placeholder", .placeholder),
                      ("hidden", .hidden),
                      ("HIDDEN", .hidden),
                      (" Placeholder ", .placeholder),
                      ("", .automatic),
                      ("lazy", .automatic)])
    func strategyNameIsParsed(name: String, strategy: MindboxEmbeddedBlockLoadingStrategy) throws {
        let nib = NibFixture()
        let view = try nib.makeUnbuiltBlock()
        view.setValue("stories", forKey: "placeSystemName")
        view.setValue(120, forKey: "height")
        view.setValue(name, forKey: "loadingStrategyName")

        view.awakeFromNib()

        #expect(view.loadingStrategy == strategy)
    }

    @Test("A timeout left at zero in Interface Builder means the SDK default",
          arguments: [(0.0, nil), (-1.0, nil), (5.0, 5.0)] as [(Double, TimeInterval?)])
    func zeroTimeoutMeansDefault(inspectable: Double, timeout: TimeInterval?) {
        #expect(MindboxEmbeddedBlockView.timeout(fromInspectableSeconds: inspectable) == timeout)
    }

    @Test("The timeout inspectable reads back in seconds, the unit of the initializer's timeout")
    func timeoutInspectableIsInSeconds() throws {
        let nib = NibFixture()

        let view = try nib.loadConfiguredBlock()

        #expect(view.timeoutSeconds == 5)
    }

    // MARK: - After the block is built

    /// The setters are not public, so a write after the build can come only the way Interface
    /// Builder writes: through key-value coding.
    @Test("Inspectables given after the block is built are ignored")
    func inspectablesAfterBuildAreIgnored() throws {
        let nib = NibFixture()
        let view = try nib.loadConfiguredBlock()

        view.setValue("other", forKey: "placeSystemName")
        view.setValue(200, forKey: "height")
        view.setValue("hidden", forKey: "loadingStrategyName")
        view.setValue(1, forKey: "timeoutSeconds")
        view.setValue(true, forKey: "animatesReveal")

        #expect(view.placeSystemName == "Stories")
        #expect(view.intrinsicContentSize.height == 96)
        #expect(view.loadingStrategy == .placeholder)
        #expect(view.timeoutSeconds == 5)
        #expect(view.animatesReveal == false)
    }

    @Test("A block built from code ignores the inspectables the same way")
    func codeBlockIgnoresInspectables() {
        let nib = NibFixture()
        let view = MindboxEmbeddedBlockView(placeSystemName: "block-id", height: 120, loadingStrategy: .placeholder)

        view.setValue("other", forKey: "placeSystemName")
        view.setValue(200, forKey: "height")

        #expect(view.placeSystemName == "block-id")
        #expect(view.intrinsicContentSize.height == 120)
        #expect(nib.factory.requestedPlaces == ["block-id"])
    }

    // MARK: - Content

    @Test("A block from a nib starts its content on entering a window and shows it")
    func nibBlockStartsContentInWindow() async throws {
        let nib = NibFixture()
        let view = try nib.loadConfiguredBlock()
        let delegate = EmbeddedBlockViewDelegateMock()
        view.delegate = delegate

        nib.window.addSubview(view)
        let page = try #require(nib.page(for: "Stories"))
        page.reportRendered(1)
        await mainQueueTurn()

        #expect(delegate.events == [.loaded])
        #expect(view.intrinsicContentSize.height == 96)
    }

    /// A view decoded outside a nib — an archive clone, say — never gets `awakeFromNib`. It must
    /// not crash on its dependencies; the window is the latest moment to build it.
    @Test("A decoded block that never got awakeFromNib builds itself on entering a window")
    func unbuiltBlockBuildsOnEnteringWindow() throws {
        let nib = NibFixture()
        let view = try nib.makeUnbuiltBlock()
        view.setValue("stories", forKey: "placeSystemName")
        view.setValue(120, forKey: "height")
        view.setValue("placeholder", forKey: "loadingStrategyName")

        nib.window.addSubview(view)

        #expect(nib.factory.requestedPlaces == ["stories"])
        #expect(view.intrinsicContentSize.height == 120)
        // Content started: the place was resolved and its page made.
        #expect(nib.page(for: "stories") != nil)
    }

    // MARK: - Helpers

    private func mainQueueTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

/// The nib path reaches the SDK through DI, which is process-global: the fixture swaps the
/// container for the test and restores it when it goes.
@MainActor
private final class NibFixture {

    let factory = PerPlaceProviderFactory()

    let memory = EmbeddedBlockPlaceMemoryMock()

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private let savedBuilder = MBInject.buildTestContainer

    private let savedMode = MBInject.mode

    init() {
        let factory = factory
        let memory = memory
        MBInject.buildTestContainer = {
            let container = MBContainer()
            container.register(EmbeddedBlockContentProviderMaking.self) { factory }
            container.register(EmbeddedBlockPlaceRemembering.self) { memory }
            return container
        }
        MBInject.mode = .test
    }

    deinit {
        MBInject.buildTestContainer = savedBuilder
        MBInject.mode = savedMode
    }

    /// The page the block of this place loaded, once the block started its content.
    func page(for place: String) -> EmbeddedBlockPageMock? {
        factory.beds[place]?.page
    }

    /// The first block of the fixture nib: every inspectable filled in.
    func loadConfiguredBlock() throws -> MindboxEmbeddedBlockView {
        try loadBlocks()[0]
    }

    /// The second block of the fixture nib: the place name and the height only.
    func loadDefaultBlock() throws -> MindboxEmbeddedBlockView {
        try loadBlocks()[1]
    }

    private func loadBlocks() throws -> [MindboxEmbeddedBlockView] {
        let nib = UINib(nibName: "EmbeddedBlockNibFixture", bundle: Bundle(for: MindboxTests.self))
        let views = nib.instantiate(withOwner: nil).compactMap { $0 as? MindboxEmbeddedBlockView }
        try #require(views.count == 2)
        return views
    }

    /// A block that has gone through `init?(coder:)` and nothing else — the state a nib-loaded
    /// block is in while Interface Builder's values are being applied, before `awakeFromNib`.
    func makeUnbuiltBlock() throws -> MindboxEmbeddedBlockView {
        let archived = try NSKeyedArchiver.archivedData(withRootObject: UIView(frame: .zero), requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archived)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(MindboxEmbeddedBlockView.self, forClassName: "UIView")
        let view = unarchiver.decodeObject(of: MindboxEmbeddedBlockView.self, forKey: NSKeyedArchiveRootObjectKey)
        return try #require(view)
    }
}

/// Every block gets a provider of its own, the way the SDK's factory makes them: the nib holds two
/// blocks, and a provider shared between them would report to the last one wired.
private final class PerPlaceProviderFactory: EmbeddedBlockContentProviderMaking {

    private(set) var requestedPlaces: [String] = []

    private(set) var beds: [String: EmbeddedBlockTestBed] = [:]

    func makeProvider(placeSystemName: String) -> EmbeddedBlockWebViewProvider {
        requestedPlaces.append(placeSystemName)
        let bed = EmbeddedBlockTestBed(placeSystemName: placeSystemName)
        beds[placeSystemName] = bed
        return bed.provider
    }
}
