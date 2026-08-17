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

        block.page?.reportRendered(1)

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

        block.page?.reportRendered(0)

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

        block.page?.reportRendered(1)

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

        block.page?.reportRendered(1)
        let content = try #require(block.page?.view)
        block.page?.failLoad()

        #expect(content.superview == nil)
        #expect(block.view.intrinsicContentSize.height == 0)
    }

    @Test("Empty content is detached")
    func emptyContentIsDetached() throws {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.reportRendered(1)
        let content = try #require(block.page?.view)
        block.page?.reportRendered(0)

        #expect(content.superview == nil)
    }

    /// A reloaded block must not drag the dropped page's view into the new attempt.
    @Test("Reload detaches the content of the dropped page")
    func reloadDetachesOldContent() throws {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.reportRendered(1)
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

        block.page?.reportRendered(1)
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

        block.page?.reportRendered(1)
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

        block.page?.reportRendered(1)
        block.page?.reportRendered(0)

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
        block.page?.reportRendered(1)
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
        block.page?.reportRendered(1)
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

        // The attempt is genuinely new — a new page is built and loads...
        #expect(block.bed.pageFactory.pages.count == 2)
        #expect(block.page?.loadCount == 1)
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
        block.page?.reportRendered(1)
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

    /// The host may give a block its own patience for the config answer — the same knob Android
    /// exposes as an XML attribute. What the host cannot do is break the block with it: a
    /// non-positive value would collapse every block before the config had a chance, so it is
    /// reported and replaced with the default.
    @Test("A custom config timeout is taken as given, a broken one falls back",
          arguments: [(nil as TimeInterval?, TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)),
                      (TimeInterval(12), TimeInterval(12)),
                      (TimeInterval(0), TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)),
                      (TimeInterval(-5), TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds))])
    func configTimeoutIsSanitized(given: TimeInterval?, effective: TimeInterval) {
        #expect(MindboxEmbeddedBlockView.sanitizedConfigTimeout(given, placeSystemName: "block") == effective)
    }

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
        block.page?.reportRendered(1)
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
    /// `EmbeddedBlockWaitBudget` itself.
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

    /// The block waits twice, and the two waits are not the same thing. Learning what to show can cost a
    /// config fetch, so it gets the long budget — and running out of it means "nothing to show", not
    /// "broken": the block collapses without an error screen and the host hears the outcome once.
    @Test("A block that never learned what to show collapses as empty")
    func neverAnsweredBlockCollapsesAsEmpty() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.view.errorView = UIView()
        block.bed.resolver.isDeferred = true
        block.attachToWindow()
        await mainQueueTurn()

        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed])
    }

    /// The other wait: the page was built and stayed silent. That is a breakage, so the error screen
    /// applies and the block keeps the space it was given.
    @Test("A page that was built and stayed silent fails")
    func silentBuiltPageFails() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()
        await mainQueueTurn()

        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.subviews.contains(errorView))
        #expect(delegate.events == [.failed])
    }

    /// And the switch between the two waits restarts the count: a page that arrives after most of the
    /// answer budget was spent still gets its own full patience, not the remainder.
    @Test("The answer restarts the waiting budget")
    func answerRestartsTheBudget() async {
        let block = BlockFixture()
        block.bed.resolver.isDeferred = true
        block.attachToWindow()
        await mainQueueTurn()

        block.waitBudgetBed.clock.advance(block.waitBudgetBed.duration - 1)
        block.bed.resolver.flush()
        await mainQueueTurn()

        // Armed anew for the whole budget: almost all of it went on waiting for the answer, and the
        // page is not charged for that.
        #expect(block.waitBudgetBed.scheduler.lastDelay == block.waitBudgetBed.duration)
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
        #expect(block.waitBudgetBed.scheduler.lastDelay == nil)
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
        block.page?.reportRendered(1)
        await mainQueueTurn()

        block.view.reload()
        await mainQueueTurn()
        block.page?.reportRendered(1)
        await mainQueueTurn()

        #expect(block.bed.resolver.resolveCount == 2)
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
        block.page?.reportRendered(1)

        block.view.reload()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(delegate.events.last == .failed)
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
    let waitBudgetBed: EmbeddedBlockWaitBudgetBed

    let view: MindboxEmbeddedBlockView

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    var page: EmbeddedBlockPageMock? { bed.page }

    init(height: CGFloat = 120,
         resolution: EmbeddedBlockResolution = .content(.stub)) {
        let bed = EmbeddedBlockTestBed(resolution: resolution)
        let waitBudgetBed = EmbeddedBlockWaitBudgetBed()
        self.bed = bed
        self.waitBudgetBed = waitBudgetBed
        self.view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                             height: height,
                                             contentProvider: bed.provider,
                                             waitBudget: waitBudgetBed.budget)
    }

    func attachToWindow() {
        window.addSubview(view)
    }

    func removeFromWindow() {
        view.removeFromSuperview()
    }

    /// Declares that the waiting budget has run out.
    func expireTimeout() {
        waitBudgetBed.scheduler.fireAll()
    }

    func enterBackground() {
        waitBudgetBed.enterBackground()
    }

    func enterForeground() {
        waitBudgetBed.enterForeground()
    }
}
