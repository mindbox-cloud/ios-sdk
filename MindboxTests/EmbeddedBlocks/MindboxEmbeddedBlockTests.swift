//
//  MindboxEmbeddedBlockTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

#if canImport(SwiftUI)
import Testing
import SwiftUI
@testable import Mindbox

/// The block logic lives in the UIKit container, so only what the SwiftUI wrapper owns is checked
/// here: the modifier contract and the way the wrapper sets the container up for the layers it
/// draws itself. The deferred presentation writes are covered by `EmbeddedBlockCoordinatorTests`.
///
/// The suite is not marked `@available(iOS 13.0, *)` — the `@Suite`/`@Test` macros reject such
/// declarations. The test target builds for iOS 12, so each test opens SwiftUI availability for
/// itself with `guard #available`, and helpers carry the annotation.
@Suite("MindboxEmbeddedBlock SwiftUI wrapper", .tags(.embeddedBlocks))
@MainActor
struct MindboxEmbeddedBlockTests {

    // MARK: - Modifiers

    /// The modifier contract rests on value semantics: a modifier must return a new block, not
    /// mutate the one it was applied to, otherwise the same block reused in a layout with
    /// different dressing would drag someone else's placeholder along.
    @Test("Bare block has neither a placeholder nor an error view")
    func bareBlockHasNoCustomViews() {
        guard #available(iOS 13.0, *) else { return }

        let block = MindboxEmbeddedBlock(id: "stories", height: 104)

        #expect(block.placeholderBuilder == nil)
        #expect(block.errorBuilder == nil)
    }

    @Test("Placeholder modifier sets the placeholder and leaves the error view alone")
    func placeholderModifierSetsOnlyThePlaceholder() {
        guard #available(iOS 13.0, *) else { return }

        let block = MindboxEmbeddedBlock(id: "stories", height: 104)
            .placeholder { Color.gray }

        #expect(block.placeholderBuilder != nil)
        #expect(block.errorBuilder == nil)
    }

    @Test("Error view modifier sets the error view and leaves the placeholder alone")
    func errorViewModifierSetsOnlyTheErrorView() {
        guard #available(iOS 13.0, *) else { return }

        let block = MindboxEmbeddedBlock(id: "stories", height: 104)
            .errorView { Text("no stories") }

        #expect(block.errorBuilder != nil)
        #expect(block.placeholderBuilder == nil)
    }

    @Test("Both modifiers compose in either order")
    func bothModifiersCompose() {
        guard #available(iOS 13.0, *) else { return }

        let placeholderFirst = MindboxEmbeddedBlock(id: "stories", height: 104)
            .placeholder { Color.gray }
            .errorView { Text("no stories") }

        let errorFirst = MindboxEmbeddedBlock(id: "stories", height: 104)
            .errorView { Text("no stories") }
            .placeholder { Color.gray }

        #expect(placeholderFirst.placeholderBuilder != nil)
        #expect(placeholderFirst.errorBuilder != nil)
        #expect(errorFirst.placeholderBuilder != nil)
        #expect(errorFirst.errorBuilder != nil)
    }

    @Test("Modifier returns a copy and does not touch the block it was applied to")
    func modifierDoesNotMutateTheOriginal() {
        guard #available(iOS 13.0, *) else { return }

        let bare = MindboxEmbeddedBlock(id: "stories", height: 104)

        let decorated = bare
            .placeholder { Color.gray }
            .errorView { Text("no stories") }

        #expect(bare.placeholderBuilder == nil)
        #expect(bare.errorBuilder == nil)
        #expect(decorated.placeholderBuilder != nil)
        #expect(decorated.errorBuilder != nil)
    }

    @Test("Applying a modifier twice keeps the last view")
    func repeatedModifierKeepsTheLastView() {
        guard #available(iOS 13.0, *) else { return }

        let log = BuildLog()

        let block = MindboxEmbeddedBlock(id: "stories", height: 104)
            .placeholder { ProbeView("first", log: log) }
            .placeholder { ProbeView("second", log: log) }

        _ = block.placeholderBuilder?()

        #expect(log.tags == ["second"])
    }

    // MARK: - Host layers

    /// The wrapper draws its own placeholder itself, so the container gets a transparent stand-in:
    /// otherwise the SDK shimmer would show through under the host's placeholder.
    @Test("Custom placeholder replaces the SDK shimmer with a transparent stand-in")
    func customPlaceholderReplacesTheShimmer() throws {
        guard #available(iOS 13.0, *) else { return }

        let blockView = makeBlockView()

        makeRepresentable(hasPlaceholder: true).syncStandIns(in: blockView)

        let standIn = try #require(blockView.placeholderView)
        #expect(standIn.superview === blockView)
        #expect(blockView.subviews.contains { $0 is EmbeddedBlockShimmerView } == false)
        // Touches go to the SwiftUI layer above, not to the stand-in below it.
        #expect(standIn.isUserInteractionEnabled == false)
    }

    @Test("Block without a custom placeholder keeps the SDK shimmer")
    func bareBlockKeepsTheShimmer() {
        guard #available(iOS 13.0, *) else { return }

        let blockView = makeBlockView()

        makeRepresentable().syncStandIns(in: blockView)

        #expect(blockView.placeholderView == nil)
        #expect(blockView.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    /// The container agrees to keep its height on a failure only by an assigned `errorView`, so a
    /// stand-in is needed here too — otherwise the SwiftUI error screen would be drawn in a
    /// collapsed block.
    @Test("Custom error view opts the container into showing the failure")
    func customErrorViewOptsIntoShowingTheFailure() {
        guard #available(iOS 13.0, *) else { return }

        let blockView = makeBlockView()

        makeRepresentable(hasErrorView: true).syncStandIns(in: blockView)

        #expect(blockView.errorView != nil)
    }

    @Test("Block without a custom error view leaves the container collapsing")
    func bareBlockLeavesTheContainerCollapsing() {
        guard #available(iOS 13.0, *) else { return }

        let blockView = makeBlockView()

        makeRepresentable().syncStandIns(in: blockView)

        #expect(blockView.errorView == nil)
    }

    /// A modifier may be applied conditionally: a layer that appeared after the block was created
    /// must reach the container, and one that disappeared must stop holding its space.
    @Test("Layers added and dropped after creation take effect")
    func layersAddedAndDroppedAfterCreationTakeEffect() {
        guard #available(iOS 13.0, *) else { return }

        let blockView = makeBlockView()
        makeRepresentable().syncStandIns(in: blockView)

        makeRepresentable(hasPlaceholder: true, hasErrorView: true).syncStandIns(in: blockView)

        #expect(blockView.placeholderView != nil)
        #expect(blockView.errorView != nil)

        makeRepresentable().syncStandIns(in: blockView)

        #expect(blockView.placeholderView == nil)
        #expect(blockView.errorView == nil)
    }

    /// An update without changes must not cost the container a rebuild of layers and constraints:
    /// `updateUIView` is called on every pass of the host's body.
    @Test("Repeated updates keep the very same stand-ins")
    func repeatedUpdatesKeepTheSameStandIns() throws {
        guard #available(iOS 13.0, *) else { return }

        let blockView = makeBlockView()
        let representable = makeRepresentable(hasPlaceholder: true, hasErrorView: true)
        representable.syncStandIns(in: blockView)
        let placeholder = try #require(blockView.placeholderView)
        let errorView = try #require(blockView.errorView)

        representable.syncStandIns(in: blockView)

        #expect(blockView.placeholderView === placeholder)
        #expect(blockView.errorView === errorView)
    }

    // MARK: - Helpers

    /// A container with substituted dependencies: the wrapper loads nothing itself, its job is to
    /// set the container up correctly, so no window or live content is needed here.
    private func makeBlockView() -> MindboxEmbeddedBlockView {
        MindboxEmbeddedBlockView(id: "stories",
                                 height: 104,
                                 contentProvider: EmbeddedBlockTestBed().provider)
    }

    @available(iOS 13.0, *)
    private func makeRepresentable(hasPlaceholder: Bool = false,
                                   hasErrorView: Bool = false) -> EmbeddedBlockRepresentable {
        let presentation = EmbeddedBlockPresentation(layer: .placeholder, height: 104)
        return EmbeddedBlockRepresentable(id: "stories",
                                          height: 104,
                                          presentation: .constant(presentation),
                                          onLoad: nil,
                                          onFail: nil,
                                          hasPlaceholder: hasPlaceholder,
                                          hasErrorView: hasErrorView)
    }
}

/// Which views the block actually built. `AnyView` cannot be looked into from outside, so the view
/// itself leaves the mark at the moment it is created.
private final class BuildLog {
    var tags: [String] = []
}

@available(iOS 13.0, *)
private struct ProbeView: View {

    init(_ tag: String, log: BuildLog) {
        log.tags.append(tag)
    }

    var body: some View { Color.clear }
}
#endif
