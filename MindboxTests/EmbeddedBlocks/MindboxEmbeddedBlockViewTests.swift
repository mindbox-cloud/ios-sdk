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

    @Test("An error view assigned while the failure is shown replaces the one on screen")
    func errorViewAssignedMidFailureReplacesTheShownOne() {
        let block = BlockFixture()
        let first = UIView()
        block.view.errorView = first
        block.attachToWindow()
        block.page?.failLoad()

        let second = UIView()
        block.view.errorView = second

        #expect(second.superview === block.view)
        #expect(first.superview == nil)
    }

    @Test("Taking the error view away collapses the failure it was showing")
    func errorViewRemovedMidFailureCollapsesTheBlock() {
        let block = BlockFixture()
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()
        block.page?.failLoad()
        #expect(block.view.intrinsicContentSize.height == 120)

        block.view.errorView = nil

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(errorView.superview == nil)
    }

    @Test("Taking the error view away collapses a failure still shown after a return")
    func errorViewRemovedAfterReturnCollapsesTheBlock() {
        let block = BlockFixture()
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()
        block.page?.failLoad()

        block.removeFromWindow()
        block.attachToWindow()
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(errorView.superview === block.view)

        block.view.errorView = nil

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(errorView.superview == nil)
    }

    @Test("An error view swapped after a return replaces the one still on screen")
    func errorViewSwappedAfterReturnReplacesTheShownOne() {
        let block = BlockFixture()
        let first = UIView()
        block.view.errorView = first
        block.attachToWindow()
        block.page?.failLoad()

        block.removeFromWindow()
        block.attachToWindow()

        let second = UIView()
        block.view.errorView = second

        #expect(second.superview === block.view)
        #expect(first.superview == nil)
    }

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

    @Test("Empty block collapses even with an error view set")
    func emptyBlockAlwaysCollapses() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()

        block.page?.reportRendered(0)

        #expect(block.view.intrinsicContentSize.height == 0)
    }

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

    @Test("Loading is silent: the delegate hears only outcomes")
    func loadingReportsNothing() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
    }

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

    @Test("Empty block reports didFail")
    func emptyBlockReportsDidFail() async {
        let block = BlockFixture(resolution: .empty)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
    }

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

    @Test("Every change is reported to the wrapper")
    func everyChangeIsReportedToTheWrapper() {
        let block = BlockFixture()
        block.attachToWindow()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.page?.reportRendered(1)
        block.page?.reportRendered(0)

        #expect(appearance.values == [.placeholder, .content, .collapsed])
    }

    @Test("Failed block without an error view reports a collapsed block")
    func failedBlockReportsCollapsed() {
        let block = BlockFixture()
        block.attachToWindow()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.page?.failLoad()

        #expect(appearance.last == .collapsed)
    }

    @Test("Failed block with an error view reports the error appearance")
    func failedBlockWithErrorViewReportsError() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.page?.failLoad()

        #expect(appearance.last == .error)
    }

    @Test("Reload reports the placeholder appearance again")
    func reloadReportsPlaceholderAgain() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.reportRendered(3)
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.view.reload()

        #expect(appearance.values == [.content, .placeholder])
    }

    @Test("Block that failed with an error view keeps it on a retry")
    func failedBlockWithErrorViewKeepsIt() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()
        block.page?.failLoad()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.removeFromWindow()
        block.attachToWindow()

        #expect(appearance.values.allSatisfy { $0 == .error })
    }

    @Test("A collapsed settled block stays collapsed on retry even if errorView is assigned after collapse")
    func collapsedSettledBlockStaysCollapsedEvenWithLateErrorView() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()
        #expect(block.view.intrinsicContentSize.height == 0)

        let errorView = UIView()
        block.view.errorView = errorView

        block.removeFromWindow()
        block.attachToWindow()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(errorView.superview == nil)
    }

    @Test("A failed settled block with error screen stays collapsed on retry when errorView is removed")
    func failedSettledBlockStaysCollapsedWhenErrorViewRemoved() {
        let block = BlockFixture()
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()
        block.page?.failLoad()
        #expect(block.view.intrinsicContentSize.height == 120)

        block.view.errorView = nil
        #expect(block.view.intrinsicContentSize.height == 0)

        block.removeFromWindow()
        block.attachToWindow()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
    }

    @Test("A reload resets the settled state and allows error view to show on the next failure")
    func reloadResetsSettledStateAndAllowsErrorViewAgain() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()
        #expect(block.view.intrinsicContentSize.height == 0)

        let errorView = UIView()
        block.view.errorView = errorView

        block.view.reload()
        block.page?.failLoad()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(errorView.superview === block.view)
    }

    @Test("Reload after a failure with an error view shows the placeholder")
    func reloadAfterErrorViewShowsThePlaceholder() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()
        block.page?.failLoad()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.view.reload()

        #expect(appearance.values == [.error, .placeholder])
    }

    // MARK: - Lifecycle

    @Test("Entering and leaving a window starts and stops the content")
    func windowMembershipDrivesTheContent() {
        let block = BlockFixture()

        #expect(block.bed.resolver.resolveCount == 0)

        block.attachToWindow()
        #expect(block.page?.loadCount == 1)
        #expect(block.page?.cancelCount == 0)

        block.removeFromWindow()
        #expect(block.page?.cancelCount == 0)
        #expect(block.page?.isUserPresent == false)
    }

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

        #expect(block.bed.pageFactory.pages.count == 2)
        #expect(block.page?.loadCount == 1)
        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed])
    }

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

    @Test("Reload after a collapse shows the placeholder again")
    func reloadAfterCollapseShowsThePlaceholder() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        block.view.reload()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

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

    /// The same knob Android exposes as an XML attribute.
    @Test("A custom timeout is taken as given, a broken one falls back",
          arguments: [(nil as TimeInterval?, TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)),
                      (TimeInterval(12), TimeInterval(12)),
                      (TimeInterval(0), TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds)),
                      (TimeInterval(-5), TimeInterval(Constants.EmbeddedBlock.answerTimeoutSeconds))])
    func timeoutIsSanitized(given: TimeInterval?, effective: TimeInterval) {
        #expect(MindboxEmbeddedBlockView.sanitizedTimeout(given, placeSystemName: "block") == effective)
    }

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

    @Test("The answer restarts the waiting budget")
    func answerRestartsTheBudget() async {
        let block = BlockFixture()
        block.bed.resolver.isDeferred = true
        block.attachToWindow()
        await mainQueueTurn()

        block.waitBudgetBed.clock.advance(block.waitBudgetBed.duration - 1)
        block.bed.resolver.flush()
        await mainQueueTurn()

        #expect(block.waitBudgetBed.scheduler.lastDelay == block.waitBudgetBed.duration)
    }

    /// The only test on real main-queue timing: the container builds the budget's duration itself
    /// and no seam shows it. 50 ms is the answer timeout; the page's own budget is seconds long.
    @Test("A block waits the answer timeout for its answer and the page's own budget for the page")
    func waitBudgetFollowsTheLoadingPhase() async throws {
        let awaitingAnswer = RealBudgetBlockFixture(timeout: 0.05)
        awaitingAnswer.bed.resolver.isDeferred = true
        awaitingAnswer.attachToWindow()

        try await waitForCollapse(of: awaitingAnswer.view)

        #expect(awaitingAnswer.view.intrinsicContentSize.height == 0)

        let withPage = RealBudgetBlockFixture(timeout: 0.05)
        let delegate = EmbeddedBlockViewDelegateMock()
        withPage.view.delegate = delegate
        withPage.attachToWindow()

        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(withPage.view.intrinsicContentSize.height == 120)
        #expect(delegate.events.isEmpty)
    }

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

    @Test("Reload outside a window does nothing")
    func reloadOutsideWindowDoesNothing() {
        let block = BlockFixture()

        block.view.reload()

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
    }

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

    // MARK: - Appearance observer

    @Test("Appearance observer reports the current value on subscribe")
    func appearanceObserverReportsCurrentValueOnSubscribe() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        #expect(appearance.values == [.collapsed])
    }

    @Test("Appearance observer reports the collapse of a failed block")
    func appearanceObserverReportsTheCollapse() {
        let block = BlockFixture()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }
        block.attachToWindow()

        block.page?.failLoad()

        #expect(appearance.last == .collapsed)
    }

    @Test("Block that loads and shows content never reports a collapse")
    func shownBlockNeverReportsCollapse() {
        let block = BlockFixture()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }
        block.attachToWindow()

        block.page?.reportRendered(3)

        #expect(appearance.last == .content)
        #expect(appearance.wasAlwaysVisible)
    }

    @Test("Appearance observer follows the error view opt-in")
    func appearanceObserverFollowsTheErrorViewOptIn() {
        let failed = BlockFixture()
        let failedAppearance = EmbeddedBlockAppearanceSpy()
        failed.view.errorView = UIView()
        failed.view.setAppearanceObserver { failedAppearance.record($0) }
        failed.attachToWindow()

        failed.page?.failLoad()

        #expect(failedAppearance.last == .error)

        let empty = BlockFixture(resolution: .empty)
        let emptyAppearance = EmbeddedBlockAppearanceSpy()
        empty.view.errorView = UIView()
        empty.view.setAppearanceObserver { emptyAppearance.record($0) }

        empty.attachToWindow()

        #expect(emptyAppearance.last == .collapsed)
    }

    // MARK: - Host visibility

    @Test("Host-hidden block does not start when it enters a window")
    func hostHiddenBlockDoesNotStartInWindow() {
        let block = BlockFixture()
        block.view.setHostVisible(false)

        block.attachToWindow()

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
        #expect(block.waitBudgetBed.scheduler.lastDelay == nil)
    }

    @Test("Host-shown block in a window starts its content")
    func hostShownBlockStartsContent() {
        let block = BlockFixture()
        block.view.setHostVisible(false)
        block.attachToWindow()

        block.view.setHostVisible(true)

        #expect(block.bed.resolver.resolveCount == 1)
        #expect(block.page?.loadCount == 1)
    }

    @Test("Host visibility alone does not start a block outside a window")
    func hostVisibilityAloneStartsNothing() {
        let block = BlockFixture()

        block.view.setHostVisible(false)
        block.view.setHostVisible(true)

        #expect(block.bed.resolver.resolveCount == 0)
        #expect(block.bed.pageFactory.pages.isEmpty)
    }

    @Test("Host-hidden block pauses its content and keeps its page")
    func hostHiddenBlockPausesContent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.setHostVisible(false)

        #expect(block.page?.isUserPresent == false)
        #expect(block.page?.cancelCount == 0)
    }

    @Test("Repeated host visibility changes nothing")
    func repeatedHostVisibilityIsIdempotent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.setHostVisible(false)
        block.view.setHostVisible(false)

        #expect(block.page?.isUserPresent == false)
        #expect(block.page?.cancelCount == 0)
        #expect(block.bed.pageFactory.pages.count == 1)
    }

    @Test("Block hidden and shown again keeps its page")
    func hostHiddenBlockKeepsItsPage() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.setHostVisible(false)
        block.view.setHostVisible(true)

        #expect(block.bed.resolver.resolveCount == 2)
        #expect(block.bed.pageFactory.pages.count == 1)
    }

    @Test("Host visibility pauses the budget and resumes it from the remainder")
    func hostVisibilityResumesTheBudgetFromTheRemainder() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()

        block.waitBudgetBed.clock.advance(2)
        block.view.setHostVisible(false)
        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)

        block.view.setHostVisible(true)

        #expect(block.waitBudgetBed.scheduler.lastDelay == 3)

        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events == [.failed])
        #expect(block.view.intrinsicContentSize.height == 0)
    }

    @Test("Shown block hidden and shown again keeps its content and reports nothing twice")
    func hostVisibilityKeepsShownContent() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        block.page?.reportRendered(3)
        await mainQueueTurn()

        block.view.setHostVisible(false)
        block.view.setHostVisible(true)
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(delegate.events == [.loaded])
        #expect(block.bed.resolver.resolveCount == 2)
    }

    @Test("Reload on a host-hidden block does nothing")
    func reloadOnHostHiddenBlockDoesNothing() {
        let block = BlockFixture()
        block.attachToWindow()
        block.view.setHostVisible(false)

        block.view.reload()

        #expect(block.bed.pageFactory.pages.count == 1)
        #expect(block.bed.resolver.resolveCount == 1)
    }

    // MARK: - Release

    @Test("Release stops the content")
    func releaseStopsTheContent() {
        let block = BlockFixture()
        block.attachToWindow()

        block.view.release()

        #expect(block.page?.cancelCount == 1)
    }

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

    @Test("Release silences the delegate and the appearance observer")
    func releaseSilencesTheWrapper() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.delegate = delegate
        block.view.setAppearanceObserver { appearance.record($0) }
        block.attachToWindow()
        block.page?.reportRendered(3)
        await mainQueueTurn()
        let reportsBeforeRelease = appearance.values.count

        block.view.release()
        block.page?.failLoad()
        await mainQueueTurn()

        #expect(block.view.delegate == nil)
        #expect(delegate.events == [.loaded])
        #expect(appearance.values.count == reportsBeforeRelease)
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

    /// Bounded, so a block that never gives up fails the test instead of hanging it.
    private func waitForCollapse(of view: MindboxEmbeddedBlockView) async throws {
        for _ in 0..<80 {
            guard view.intrinsicContentSize.height != 0 else { return }

            try await Task.sleep(nanoseconds: 25_000_000)
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

/// A block on the waiting budget the container builds for itself, counted down by the main queue.
@MainActor
private final class RealBudgetBlockFixture {

    let bed: EmbeddedBlockTestBed

    let view: MindboxEmbeddedBlockView

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    init(timeout: TimeInterval) {
        let bed = EmbeddedBlockTestBed()
        self.bed = bed
        self.view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                             height: 120,
                                             contentProvider: bed.provider,
                                             timeout: timeout)
    }

    func attachToWindow() {
        window.addSubview(view)
    }
}
