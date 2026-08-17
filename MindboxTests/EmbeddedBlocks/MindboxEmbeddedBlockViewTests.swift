//
//  MindboxEmbeddedBlockViewTests.swift
//  MindboxTests
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@_spi(Internal) @testable import Mindbox

@Suite("MindboxEmbeddedBlockView container", .tags(.embeddedBlocks))
@MainActor
struct MindboxEmbeddedBlockViewTests {

    // MARK: - Height

    /// The block's space is claimed right away: the host set the height, and it does not change
    /// before the load outcome — otherwise the container would jump in the host's layout.
    @Test("Loading block keeps the height given at creation")
    func loadingKeepsGivenHeight() {
        let block = BlockFixture()

        #expect(block.view.intrinsicContentSize.height == 120)
        // Width is the host's business, the container does not declare it.
        #expect(block.view.intrinsicContentSize.width == UIView.noIntrinsicMetric)
    }

    @Test("Shown block keeps the same height")
    func shownBlockKeepsHeight() {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.renderContent(count: 3)

        #expect(block.view.intrinsicContentSize.height == 120)
    }

    /// The container is the only source of height, so a host laying out by frames must get the
    /// same number through the entry point it actually uses.
    @Test("sizeThatFits reports the same height as intrinsicContentSize")
    func sizeThatFitsMatchesIntrinsicHeight() {
        let block = BlockFixture(height: 96)

        let fitted = block.view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))

        #expect(fitted.height == 96)
        #expect(fitted.width == 320)
    }

    @Test("Failed block collapses the container")
    func failedBlockCollapses() {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 0)
    }

    /// The failure can be shown instead of collapsing — then the block stays the same height.
    @Test("Failed block with an error view keeps its height")
    func failedBlockWithErrorViewKeepsHeight() {
        let block = BlockFixture()
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()

        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(errorView.superview === block.view)
    }

    /// The host has already reclaimed the collapsed block's space — reopening it after the fact
    /// would jerk the layout. A late `errorView` is only remembered.
    @Test("Error view assigned after the collapse does not expand the block")
    func lateErrorViewDoesNotExpandCollapsedBlock() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        let errorView = UIView()
        block.view.errorView = errorView

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(errorView.superview == nil)
    }

    /// A remembered `errorView` takes effect on the next load: a new attempt, a failure again —
    /// and now the block shows the error instead of collapsing.
    @Test("Error view assigned after the collapse applies on the next load")
    func lateErrorViewAppliesOnNextLoad() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()
        let errorView = UIView()
        block.view.errorView = errorView

        block.view.reload()
        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(errorView.superview === block.view)
    }

    /// An empty block always collapses: there is nothing to show, and there was no failure.
    @Test("Empty block collapses even with an error view set")
    func emptyBlockAlwaysCollapses() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()

        block.page?.renderContent(count: 0)

        #expect(block.view.intrinsicContentSize.height == 0)
    }

    /// A host that asked for a negative height must not get an unsatisfiable set of constraints.
    @Test("Negative height given by the host is clamped to zero")
    func negativeHeightIsClamped() {
        let block = BlockFixture(height: -50)

        #expect(block.view.intrinsicContentSize.height == 0)
    }

    // MARK: - Content view

    @Test("Shown content is attached and pinned to the container")
    func shownContentIsPinned() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.renderContent(count: 3)

        let content = try #require(block.page?.view)
        #expect(content.superview === block.view)
        #expect(content.translatesAutoresizingMaskIntoConstraints == false)
        // Four edges: the content always fills the container it was given.
        #expect(block.view.constraints.count == 4)
    }

    @Test("Failed content is detached")
    func failedContentIsDetached() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.renderContent(count: 3)
        let content = try #require(block.page?.view)
        block.page?.failLoad()

        #expect(content.superview == nil)
        #expect(block.view.intrinsicContentSize.height == 0)
    }

    /// A page that drew nothing has a view all the same — it just never goes on screen.
    @Test("A block that renders nothing attaches no content")
    func emptyBlockAttachesNoContent() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.renderContent(count: 0)

        let content = try #require(block.page?.view)
        #expect(content.superview == nil)
    }

    /// Content that did go on screen has to come off it again when the block stops showing.
    @Test("Shown content is detached when the block collapses")
    func shownContentIsDetachedOnCollapse() throws {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.renderContent(count: 3)
        let content = try #require(block.page?.view)

        block.page?.failLoad()

        #expect(content.superview == nil)
    }

    /// A reloaded block must not drag the dropped page's view into the new attempt.
    @Test("Reload detaches the content of the dropped page")
    func reloadDetachesOldContent() throws {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.renderContent(count: 3)
        let oldContent = try #require(block.page?.view)

        block.view.reload()

        #expect(oldContent.superview == nil)
    }

    // MARK: - Events

    /// There are two public outcomes — shown and not shown; loading is not an outcome, and the
    /// host does not hear about it.
    @Test("Loading is silent: the delegate hears only outcomes")
    func loadingReportsNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
    }

    /// A block that never entered a window loads nothing — and has nothing to report.
    @Test("Block outside a window reports nothing and loads nothing")
    func blockOutsideWindowDoesNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
        #expect(block.bed.resolver.resolveCount == 0)
    }

    @Test("Shown block reports didLoad")
    func shownBlockReportsDidLoad() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.renderContent(count: 3)
        await mainQueueTurn()

        #expect(delegate.events == [.loaded])
    }

    @Test("Failed block reports didFail")
    func failedBlockReportsDidFail() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.failLoad()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// "Empty" is the same not-shown outcome for the host as a failure: it has no event of its own.
    @Test("Empty block reports didFail")
    func emptyBlockReportsDidFail() async {
        let block = BlockFixture(resolution: .empty)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// A host assigning the delegate in `viewDidLoad` would otherwise miss an outcome that already
    /// happened.
    @Test("Delegate assigned after the outcome still receives it")
    func lateDelegateStillReceivesOutcome() async {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()
        await mainQueueTurn()

        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// A host routinely reassigns the delegate on every reused cell. It must not be handed an
    /// outcome already heard: on the outcome it rebuilds the layout, and rebuilding the layout
    /// reassigns the delegate again — the block would spin in a loop while scrolling.
    @Test("Reassigning the same delegate does not repeat the outcome")
    func sameDelegateReassignedHearsTheOutcomeOnce() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.view.delegate = delegate
        await mainQueueTurn()
        block.view.delegate = delegate
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    /// A different delegate, however, is a different subscriber, and it must hear an outcome that
    /// already happened.
    @Test("A delegate replacing another one still receives the outcome")
    func replacingDelegateReceivesTheOutcome() async {
        let block = BlockFixture()
        let first = EmbeddedBlockViewDelegateMock()
        block.view.delegate = first
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        let second = EmbeddedBlockViewDelegateMock()
        block.view.delegate = second
        await mainQueueTurn()

        #expect(first.events == [.failed])
        #expect(second.events == [.failed])
    }

    /// Content may fail again on returning to the window — that is no reason to turn the outcome
    /// into a stream of identical events.
    @Test("Repeated failure is reported once")
    func repeatedFailureIsReportedOnce() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.failLoad()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

    @Test("Block that fails after being shown reports both outcomes in order")
    func failureAfterLoadReportsBothOutcomes() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.renderContent(count: 3)
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        #expect(delegate.events == [.loaded, .failed])
    }

    // MARK: - Presentation for the SwiftUI wrapper

    /// SwiftUI does not read `intrinsicContentSize` on the representable view and draws the host's
    /// layers itself, so the wrapper needs both the height and the layer — and what it receives
    /// must match what the container actually shows.
    @Test("Every change is pushed to the SwiftUI wrapper as a layer and a height")
    func presentationChangesArePushedToWrapper() {
        let block = BlockFixture()
        block.attachToWindow()
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.page?.renderContent(count: 3)
        block.page?.failLoad()

        #expect(reported == [EmbeddedBlockPresentation(layer: .content, height: 120),
                             EmbeddedBlockPresentation(layer: .nothing, height: 0)])
    }

    /// A failure without an error screen is, for the wrapper, the same collapsed block as an empty
    /// one: there is nothing to draw.
    @Test("Failed block without an error view reports nothing to show")
    func failedBlockReportsNothingToShow() {
        let block = BlockFixture()
        block.attachToWindow()
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.page?.failLoad()

        #expect(reported == [EmbeddedBlockPresentation(layer: .nothing, height: 0)])
    }

    /// The container sees the agreement to show an error screen by the assigned `errorView` — and
    /// only then asks the wrapper to draw its layer.
    @Test("Failed block with an error view reports the error layer")
    func failedBlockWithErrorViewReportsErrorLayer() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.page?.failLoad()

        #expect(reported == [EmbeddedBlockPresentation(layer: .errorView, height: 120)])
    }

    /// A reload returns the block to loading — the wrapper must show the placeholder again.
    @Test("Reload reports the placeholder layer again")
    func reloadReportsPlaceholderLayer() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.renderContent(count: 3)
        var reported: [EmbeddedBlockPresentation] = []
        block.view.onPresentationChange = { reported.append($0) }

        block.view.reload()

        #expect(reported == [EmbeddedBlockPresentation(layer: .placeholder, height: 120)])
    }

    // MARK: - Lifecycle

    /// The host never starts or stops content by hand: the only trigger is the window.
    @Test("Entering and leaving a window starts and stops the content")
    func windowMembershipDrivesTheContent() {
        let block = BlockFixture()

        #expect(block.bed.resolver.resolveCount == 0)

        block.attachToWindow()
        #expect(block.page?.loadCount == 1)
        #expect(block.page?.cancelCount == 0)

        block.removeFromWindow()
        #expect(block.page?.cancelCount == 1)
    }

    /// The block scrolls across the screen in a feed and survives switching tabs: every such pass
    /// must not cost a reload, a flash of the shimmer, or repeated events to the host.
    @Test("Block returning to the window keeps its content as it was")
    func returningBlockKeepsItsContent() async throws {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.renderContent(count: 3)
        await mainQueueTurn()
        let content = try #require(block.page?.view)

        block.removeFromWindow()
        block.attachToWindow()
        await mainQueueTurn()

        #expect(block.page?.loadCount == 1)
        #expect(content.superview === block.view)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView } == false)
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.loaded])
    }

    /// A block that failed to show tries again on returning to the window — but the attempt does
    /// not reclaim the space the host already took back. Otherwise a collapsed block would jerk
    /// the layout to its height and flash the shimmer on every pass across the screen, showing
    /// nothing in the end.
    @Test("Collapsed block stays collapsed while it tries again")
    func collapsedBlockDoesNotReExpandWhileRetrying() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        await mainQueueTurn()

        // The attempt is genuinely new — the page loads again...
        #expect(block.page?.loadCount == 2)
        // ...but the container does not claim space for it and does not flash the shimmer.
        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed])
    }

    /// Only shown content expands the block — and then the height comes back, and the host hears
    /// that the block has finally appeared.
    @Test("Retry that succeeds gives the block its height back")
    func successfulRetryExpandsTheBlock() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        block.page?.renderContent(count: 3)
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.failed, .loaded])
    }

    /// A reload is the host's explicit consent to a full cycle again, so it claims space: the
    /// block shows the placeholder again even if it was collapsed before the reload.
    @Test("Reload after a collapse shows the placeholder again")
    func reloadAfterCollapseShowsThePlaceholder() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        block.view.reload()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    /// An empty block collapses the same way — and just as much does not reclaim its space back.
    @Test("Empty block stays collapsed when it returns to the window")
    func emptyBlockStaysCollapsedOnReturn() async {
        let block = BlockFixture(resolution: .empty)
        block.attachToWindow()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
    }

    // MARK: - Timeout

    /// The container, not the content, guarantees the host's layout will not wait forever: a
    /// silent page past its budget collapses and reports a failure.
    @Test("Silent block times out, collapses and reports didFail")
    func silentBlockTimesOut() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events == [.failed])
        // Content is stopped, so it can no longer revive the expired block.
        #expect(block.page?.cancelCount == 1)
    }

    @Test("Block shown in time is not failed by the timeout")
    func shownBlockIsNotTimedOut() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        block.page?.renderContent(count: 3)
        // A shown block has disarmed the budget, so a declared "time is up" no longer concerns it.
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.loaded])
        #expect(block.page?.cancelCount == 0)
    }

    /// Leaving the window has already stopped the content — a disarmed timeout must not fail
    /// something that is not running.
    @Test("Leaving the window disarms the timeout")
    func leavingWindowDisarmsTimeout() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        block.removeFromWindow()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    /// The loading budget counts the user's waiting time, not calendar time: nobody waits for the
    /// block in the background, and collapsing it there makes no sense — otherwise the user would
    /// come back to a block that gave up without ever being on screen. That the budget then
    /// continues from the remainder instead of being granted anew is checked by the tests of
    /// `EmbeddedBlockReadyTimeout` itself.
    @Test("Timeout pauses in the background and resumes on return")
    func timeoutPausesInBackground() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()

        block.enterBackground()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events.isEmpty)

        block.enterForeground()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events == [.failed])
    }

    /// A block outside a window loads nothing, so it needs no budget either.
    @Test("Returning from the background does not arm a timeout outside a window")
    func foregroundOutsideWindowArmsNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.enterForeground()
        block.expireTimeout()
        await mainQueueTurn()

        // The countdown did not just fail to fire — it was never armed at all.
        #expect(block.timeoutBed.scheduler.lastDelay == nil)
        #expect(delegate.events.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    // MARK: - Reload

    /// A reload takes the same path as the first start: the block returns to loading, and the
    /// host hears the new outcome in full, even if it matches the previous one.
    @Test("Reload restarts the block and reports the outcome again")
    func reloadRestartsTheBlock() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.renderContent(count: 3)
        await mainQueueTurn()

        block.view.reload()
        await mainQueueTurn()
        block.page?.renderContent(count: 3)
        await mainQueueTurn()

        #expect(block.bed.resolver.forceRefreshHistory == [false, true])
        #expect(delegate.events == [.loaded, .loaded])
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    /// Content lives only while the block is in a window: there is nothing to reload on an
    /// invisible block.
    @Test("Reload outside a window does nothing")
    func reloadOutsideWindowDoesNothing() {
        let block = BlockFixture()

        block.view.reload()

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
    }

    /// A new attempt also gets a new budget — otherwise a reloaded block would hang loading
    /// forever.
    @Test("Reload arms the timeout again")
    func reloadArmsTheTimeoutAgain() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        block.page?.renderContent(count: 3)

        block.view.reload()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events.last == .failed)
    }

    // MARK: - Visibility observer

    /// A wrapper that lays the block out itself gets exactly one bit of the container's state:
    /// whether the block takes space. The current value arrives on subscribing, so a wrapper that
    /// comes after the outcome cannot miss the collapse that came with it.
    @Test("Visibility observer reports the current value on subscribe")
    func visibilityObserverReportsCurrentValueOnSubscribe() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        let visibility = EmbeddedBlockVisibilitySpy()
        block.view.setVisibilityObserver { visibility.record($0) }

        #expect(visibility.values == [false])
    }

    @Test("Visibility observer reports the collapse of a failed block")
    func visibilityObserverReportsTheCollapse() {
        let block = BlockFixture()
        let visibility = EmbeddedBlockVisibilitySpy()
        block.view.setVisibilityObserver { visibility.record($0) }
        block.attachToWindow()

        block.page?.failLoad()

        #expect(visibility.last == false)
    }

    /// A shown block keeps the space it was given, and the wrapper must not collapse it: the report
    /// stays `true` through the whole load.
    @Test("Visibility observer stays true while the block loads and shows content")
    func visibilityObserverStaysTrueForShownBlock() {
        let block = BlockFixture()
        let visibility = EmbeddedBlockVisibilitySpy()
        block.view.setVisibilityObserver { visibility.record($0) }
        block.attachToWindow()

        block.page?.renderContent(count: 3)

        #expect(visibility.last == true)
        #expect(!visibility.values.contains(false))
    }

    /// The rule "an `errorView` keeps the space, an empty block collapses anyway" is applied by the
    /// container, and the wrapper sees only the answer — which is the whole point of a boolean.
    @Test("Visibility observer follows the error view opt-in")
    func visibilityObserverFollowsTheErrorViewOptIn() {
        let failed = BlockFixture()
        let failedVisibility = EmbeddedBlockVisibilitySpy()
        failed.view.errorView = UIView()
        failed.view.setVisibilityObserver { failedVisibility.record($0) }
        failed.attachToWindow()

        failed.page?.failLoad()

        #expect(failedVisibility.last == true)

        let empty = BlockFixture(resolution: .empty)
        let emptyVisibility = EmbeddedBlockVisibilitySpy()
        empty.view.errorView = UIView()
        empty.view.setVisibilityObserver { emptyVisibility.record($0) }

        empty.attachToWindow()

        #expect(emptyVisibility.last == false)
    }

    // MARK: - Host visibility

    /// The whole reason the hook exists: a block on a screen nobody is looking at must not spend its
    /// waiting budget — and must not even start, so no content is requested for it.
    @Test("Host-hidden block does not start when it enters a window")
    func hostHiddenBlockDoesNotStartInWindow() {
        let block = BlockFixture()
        block.view.setHostVisible(false)

        block.attachToWindow()

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
        // Not armed at all, so there is no budget to run out while the screen is out of sight.
        #expect(block.timeoutBed.scheduler.lastDelay == nil)
    }

    /// Being shown again by the wrapper is the same event as entering a window: the block starts.
    @Test("Host-shown block in a window starts its content")
    func hostShownBlockStartsContent() {
        let block = BlockFixture()
        block.view.setHostVisible(false)
        block.attachToWindow()

        block.view.setHostVisible(true)

        #expect(block.bed.resolver.resolveCount == 1)
        #expect(block.page?.loadCount == 1)
    }

    /// Both sources have to agree: the wrapper saying "shown" cannot start a block that is not in a
    /// window in the first place.
    @Test("Host visibility alone does not start a block outside a window")
    func hostVisibilityAloneStartsNothing() {
        let block = BlockFixture()

        block.view.setHostVisible(false)
        block.view.setHostVisible(true)

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
    }

    @Test("Host-hidden block stops its content")
    func hostHiddenBlockStopsContent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.setHostVisible(false)

        #expect(block.page?.cancelCount == 1)
    }

    /// Three sources drive one switch, and they repeat each other freely — the same value twice must
    /// not stop the content twice.
    @Test("Repeated host visibility changes nothing")
    func repeatedHostVisibilityIsIdempotent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.setHostVisible(false)
        block.view.setHostVisible(false)

        #expect(block.page?.cancelCount == 1)
    }

    /// A pause, not a reset — the same as leaving a window: the page that was already loaded is kept
    /// instead of being resolved and built anew.
    @Test("Block hidden and shown again keeps its page")
    func hostHiddenBlockKeepsItsPage() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.setHostVisible(false)
        block.view.setHostVisible(true)

        #expect(block.bed.resolver.resolveCount == 1)
        #expect(block.bed.pageFactory.pages.count == 1)
    }

    /// And the budget is paused, not handed back: what the block spent before it was hidden stays
    /// spent, so a wrapper toggling visibility cannot extend the wait indefinitely.
    @Test("Host visibility pauses the budget and resumes it from the remainder")
    func hostVisibilityResumesTheBudgetFromTheRemainder() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()

        block.timeoutBed.clock.advance(2)
        block.view.setHostVisible(false)
        block.expireTimeout()
        await mainQueueTurn()

        // Nobody was looking, so the block did not give up while it was hidden.
        #expect(delegate.events.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)

        block.view.setHostVisible(true)

        // Five seconds of budget, two of them already spent on screen.
        #expect(block.timeoutBed.scheduler.lastDelay == 3)

        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
        #expect(block.view.intrinsicContentSize.height == 0)
    }

    /// A block that is already shown costs nothing to hide and show: the content is there, and the
    /// host hears no second outcome for it.
    @Test("Shown block hidden and shown again keeps its content and reports nothing twice")
    func hostVisibilityKeepsShownContent() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        block.page?.renderContent(count: 3)
        await mainQueueTurn()

        block.view.setHostVisible(false)
        block.view.setHostVisible(true)
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.loaded])
        #expect(block.bed.resolver.resolveCount == 1)
    }

    /// A reload needs somebody to look at the block, and the window is no longer the only one who
    /// knows whether anybody does.
    @Test("Reload on a host-hidden block does nothing")
    func reloadOnHostHiddenBlockDoesNothing() {
        let block = BlockFixture()
        block.attachToWindow()
        block.view.setHostVisible(false)

        block.view.reload()

        #expect(block.bed.pageFactory.pages.count == 1)
        #expect(block.bed.resolver.forceRefreshHistory == [false])
    }

    // MARK: - Release

    @Test("Release stops the content")
    func releaseStopsTheContent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.release()

        #expect(block.page?.cancelCount == 1)
    }

    /// Release is final: the wrapper holds the view for as long as the platform sees fit, and a
    /// block whose screen is gone must not come back to life with it.
    @Test("Released block does not start again in a window")
    func releasedBlockDoesNotStartAgain() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.release()
        block.removeFromWindow()
        block.attachToWindow()

        #expect(block.page?.loadCount == 1)
        #expect(block.bed.resolver.resolveCount == 1)
    }

    /// Nothing reaches the wrapper after it let the block go — neither outcomes nor visibility.
    @Test("Release silences the delegate and the visibility observer")
    func releaseSilencesTheWrapper() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        let visibility = EmbeddedBlockVisibilitySpy()
        block.view.delegate = delegate
        block.view.setVisibilityObserver { visibility.record($0) }
        block.attachToWindow()
        block.page?.renderContent(count: 3)
        await mainQueueTurn()
        let reportsBeforeRelease = visibility.values.count

        block.view.release()
        block.page?.failLoad()
        await mainQueueTurn()

        #expect(block.view.delegate == nil)
        #expect(delegate.events == [.loaded])
        #expect(visibility.values.count == reportsBeforeRelease)
    }

    @Test("Repeated release changes nothing")
    func repeatedReleaseIsIdempotent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.release()
        block.view.release()

        #expect(block.page?.cancelCount == 1)
    }

    // MARK: - Helpers

    /// Outcomes are delivered on the next turn of the main queue, so a block queued after them
    /// continues only once they have run — the queue is serial and FIFO.
    private func mainQueueTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

/// A block with every dependency substituted and a live window: the window must outlive the test,
/// otherwise the view would fly out of the window mid-check and the content would stop on its own.
@MainActor
private final class BlockFixture {

    let bed: EmbeddedBlockTestBed

    /// The budget is handed to the view from outside, so "time is up" here happens on the test's
    /// command rather than through a sleep: `expireTimeout()`.
    let timeoutBed: EmbeddedBlockTimeoutBed

    let view: MindboxEmbeddedBlockView

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    var page: EmbeddedBlockPageMock? { bed.page }

    init(height: CGFloat = 120,
         resolution: EmbeddedBlockResolution = .content(.stub)) {
        let bed = EmbeddedBlockTestBed(resolution: resolution)
        let timeoutBed = EmbeddedBlockTimeoutBed()
        self.bed = bed
        self.timeoutBed = timeoutBed
        self.view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                             height: height,
                                             contentProvider: bed.provider,
                                             timeout: timeoutBed.timeout)
    }

    func attachToWindow() {
        window.addSubview(view)
    }

    func removeFromWindow() {
        view.removeFromSuperview()
    }

    /// Declares that the waiting budget has run out.
    func expireTimeout() {
        timeoutBed.scheduler.fireAll()
    }

    func enterBackground() {
        timeoutBed.enterBackground()
    }

    func enterForeground() {
        timeoutBed.enterForeground()
    }
}
