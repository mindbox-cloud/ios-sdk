//
//  EmbeddedBlockWebViewProviderTests.swift
//  MindboxTests
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

@Suite("Embedded block web view provider", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWebViewProviderTests {

    // MARK: - Loading

    @Test("Start resolves the id and loads the resolved content")
    func startResolvesAndLoads() {
        let bed = EmbeddedBlockTestBed(id: "promo")
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(bed.resolver.resolvedIds == ["promo"])
        #expect(bed.pageFactory.contents == [.stub])
        #expect(bed.page?.loadCount == 1)
        #expect(states == [.loading])
        // Before the page is ready there is no content: the container has nothing to show.
        #expect(bed.provider.contentView == nil)
    }

    @Test("Second start does not resolve or load again")
    func secondStartDoesNothing() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.start()

        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.page?.loadCount == 1)
    }

    /// A block switched off in the admin panel or unknown to it is not an error: no page is even
    /// created for it.
    @Test("Empty resolution needs no page at all")
    func emptyResolutionCreatesNoPage() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading, .empty])
        #expect(bed.pageFactory.pages.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Readiness

    /// Only the page itself reports readiness — it is the single source of truth.
    @Test("Page ready makes the content available")
    func pageReadyMakesContentAvailable() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        #expect(states == [.loading, .ready])
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// A silent page never becomes ready on its own: a loaded document says nothing about whether
    /// the block has anything to show. Such a block will be finished off by the container's
    /// timeout.
    @Test("Silent page never becomes ready on its own")
    func silentPageStaysLoading() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading])
        #expect(bed.provider.contentView == nil)
    }

    /// A page with no content is more honest saying `empty`, so a zero height is broken layout.
    @Test("Zero height in ready is a failure")
    func zeroHeightIsFailure() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.ready(height: 0))

        #expect(states.last == .failed)
        #expect(bed.provider.contentView == nil)
    }

    /// The host owns the height: the message exists in the contract, but it does not touch layout.
    @Test("Height change leaves the state alone")
    func heightChangeChangesNothing() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.send(.ready(height: 104))
        bed.page?.send(.heightChanged(height: 132))

        #expect(states == [.ready])
    }

    @Test("Page empty collapses the block")
    func pageEmptyCollapsesTheBlock() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.send(.ready(height: 104))
        bed.page?.send(.empty)

        #expect(states == [.ready, .empty])
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Debug readiness

    /// The usual rule: a loaded document says nothing about whether the block has anything to show.
    @Test("Loaded document alone does not make the block ready")
    func loadFinishAloneChangesNothing() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.finishLoad()

        #expect(states == [.loading])
        #expect(bed.provider.contentView == nil)
    }

    /// With the override on the block is shown on a loaded document — this is how UI is checked
    /// while the page cannot yet send `ready`.
    @Test("With the debug override a loaded document shows the block")
    func loadFinishMakesBlockReadyWithOverride() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.finishLoad()

        #expect(states == [.loading, .ready])
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// A page that implements the contract behaves the same with the override as without it:
    /// `ready` has already shown the block, and the document does not add a second showing.
    @Test("A page that sent ready is not shown twice by the override")
    func readyBeforeLoadFinishIsNotDuplicated() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        bed.page?.finishLoad()

        #expect(states == [.loading, .ready])
    }

    /// The override is not stronger than the page: its "nothing to show" collapses the block even
    /// with the flag on.
    @Test("The override does not swallow an empty from the page")
    func overrideDoesNotSwallowEmpty() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.finishLoad()
        bed.page?.send(.empty)

        #expect(states == [.loading, .ready, .empty])
        #expect(bed.provider.contentView == nil)
    }

    /// After `stop()` the provider stays silent entirely — the override does not change that.
    @Test("Loaded document after a stop is ignored even with the override")
    func loadFinishAfterStopIsIgnored() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        bed.provider.start()
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.finishLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// A page dropped by a reload must not show itself through the override either.
    @Test("The dropped page cannot show itself through the override")
    func droppedPageCannotFinishIntoTheNewAttempt() {
        let bed = EmbeddedBlockTestBed(treatsLoadedPageAsReady: true)
        bed.provider.start()
        let firstPage = bed.page
        bed.provider.reload()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        firstPage?.finishLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Load failure

    /// A load failure is the only thing navigation judges.
    @Test("Load failure fails the block")
    func loadFailureFailsTheBlock() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.failLoad()

        #expect(states == [.loading, .failed])
        #expect(bed.provider.contentView == nil)
    }

    @Test("Load failure after a stop is ignored")
    func loadFailureAfterStopIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.failLoad()

        #expect(states.isEmpty)
    }

    // MARK: - Page actions

    /// The core does not know the page's dictionary: everything above the core layer goes to the
    /// handler as is and does not touch the container's state.
    @Test("Page action is routed to the handler and changes no state")
    func actionIsRouted() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        let action = EmbeddedBlockPageAction(type: "openUrl", payload: ["url": "https://mindbox.ru"])
        bed.page?.send(.action(action))

        #expect(bed.actionHandler.handledActions == [action])
        #expect(states.isEmpty)
    }

    /// A stopped provider stays silent entirely — including not waking the action handler.
    @Test("Actions after a stop do not reach the handler")
    func actionsAfterStopAreIgnored() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.page?.send(.action(EmbeddedBlockPageAction(type: "openUrl", payload: [:])))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    @Test("Action from a shown block is routed")
    func actionFromShownBlockIsRouted() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions == [.openUrlStub])
    }

    /// A collapsed block does not kill the page — it stays alive and may still deliver what it
    /// scheduled. But there is no user touch behind an invisible block, and `openUrl` would take
    /// the user out of the app for no reason.
    @Test("Actions from a block collapsed as empty do not reach the handler")
    func actionsAfterEmptyAreIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.empty)
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    @Test("Actions from a failed block do not reach the handler")
    func actionsAfterFailureAreIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    /// Broken layout is the same as a block not shown: its actions are not executed either.
    @Test("Actions from a block broken by a zero height do not reach the handler")
    func actionsAfterZeroHeightAreIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.ready(height: 0))
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions.isEmpty)
    }

    /// The ban rests on the attempt's outcome, not on the page: a new attempt is live again.
    @Test("A new attempt after a failure accepts actions again")
    func retryAfterFailureAcceptsActions() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()

        bed.provider.stop()
        bed.provider.start()
        bed.page?.send(.action(.openUrlStub))

        #expect(bed.actionHandler.handledActions == [.openUrlStub])
    }

    // MARK: - Stop and restart

    /// After `stop()` the provider must stay silent — the container relies on this when it
    /// collapses expired content on its own timeout.
    @Test("Stop cancels the page and ignores what it says afterwards")
    func stopCancelsThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.stop()
        bed.page?.send(.ready(height: 104))

        #expect(bed.page?.cancelCount == 1)
        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// The container calls `start()` every time it returns to the window: there is no need to
    /// recreate the web view and ask the resolver again on every return.
    @Test("Restart reuses the same page without resolving again")
    func restartReusesThePage() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.loadCount == 2)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// The block left the screen already shown — on return it must not load again: the page
    /// remained in memory, and it is shown as is.
    @Test("Page rendered before the block left the window is shown again without a reload")
    func renderedPageIsShownAgainWithoutReload() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.page?.loadCount == 1)
        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// But a block that failed to show gets a new attempt on return — this is the only retry the
    /// block has for now.
    @Test("Failed block tries again when it comes back")
    func failedBlockTriesAgainOnReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading])
        #expect(bed.page?.loadCount == 2)
    }

    // MARK: - Live blocks

    /// The live-block counter is shared across the process, so each test uses its own id:
    /// otherwise tests running in parallel would count each other's blocks.
    @Test("Live count follows the life of a block")
    func liveCountFollowsBlockLife() {
        let id = "live-count-single"
        #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 0)

        do {
            let provider = makeProvider(id: id)
            withExtendedLifetime(provider) {
                #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 1)
            }
        }

        #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 0)
    }

    @Test("Blocks sharing an id are counted together")
    func liveCountSumsBlocksOfTheSameId() {
        let id = "live-count-shared"

        do {
            let first = makeProvider(id: id)
            let second = makeProvider(id: id)
            withExtendedLifetime((first, second)) {
                #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 2)
            }
        }

        #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 0)
    }

    @Test("Blocks with different ids are counted apart")
    func liveCountKeepsIdsApart() {
        let promo = "live-count-promo"
        let stories = "live-count-stories"

        let provider = makeProvider(id: promo)
        withExtendedLifetime(provider) {
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: promo) == 1)
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: stories) == 0)
        }
    }

    private func makeProvider(id: String) -> EmbeddedBlockWebViewProvider {
        EmbeddedBlockWebViewProvider(id: id,
                                     resolver: EmbeddedBlockResolverMock(),
                                     actionHandler: EmbeddedBlockActionHandlerMock(),
                                     makePage: { _ in EmbeddedBlockPageMock() })
    }

    /// The resolve may have arrived after the stop — then it belongs to the previous attempt.
    @Test("Resolution arriving after a stop creates nothing")
    func lateResolutionAfterStopIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.provider.stop()
        bed.resolver.flush()

        #expect(bed.pageFactory.pages.isEmpty)
        #expect(states == [.loading])
    }

    // MARK: - Reload

    @Test("Reload asks for the content again bypassing the cache and builds a new page")
    func reloadRefetchesTheContent() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        let firstPage = bed.page
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .content(.other)
        bed.provider.reload()

        #expect(bed.resolver.forceRefreshHistory == [false, true])
        #expect(bed.pageFactory.contents == [.stub, .other])
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.page !== firstPage)
        #expect(firstPage?.cancelCount == 1)
        #expect(states == [.loading])
        // Readiness starts from zero: the new page has said nothing yet.
        #expect(bed.provider.contentView == nil)
    }

    /// The old page is no longer relevant — its late messages must not show the dropped content.
    @Test("The dropped page cannot report into the new attempt")
    func droppedPageIsSilenced() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))
        let firstPage = bed.page
        bed.provider.reload()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        firstPage?.send(.ready(height: 104))
        firstPage?.failLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// The previous attempt's resolve must not replace the new page.
    @Test("Resolution arriving after a reload does not add a second page")
    func lateResolutionAfterReloadIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.reload()
        bed.resolver.flush()

        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("Reloaded block becomes ready through the same path")
    func reloadedBlockBecomesReady() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.ready(height: 104))

        bed.provider.reload()
        bed.page?.send(.ready(height: 104))

        #expect(bed.provider.contentView === bed.page?.view)
    }
}
