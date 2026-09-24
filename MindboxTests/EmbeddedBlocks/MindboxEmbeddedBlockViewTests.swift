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

    @Test("A new height resizes the container in place")
    func newHeightResizesInPlace() {
        let block = BlockFixture()

        block.view.preferredHeight = 200

        #expect(block.view.intrinsicContentSize.height == 200)
        #expect(block.view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height == 200)
    }

    @Test("A collapsed block stays collapsed whatever height it is given")
    func collapsedBlockStaysCollapsedOnNewHeight() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.failLoad()

        block.view.preferredHeight = 200

        #expect(block.view.intrinsicContentSize.height == 0)
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
        block.bed.resolver.resolution = .empty
        block.bed.announceNewConfig()

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

        #expect(delegate.events == [.failed(.networkError)])
    }

    @Test("Empty block reports didBecomeEmpty, not didFail")
    func emptyBlockReportsDidBecomeEmpty() async {
        let block = BlockFixture(resolution: .empty)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events == [.empty])
    }

    @Test("A page that rendered nothing reports didBecomeEmpty")
    func pageThatRenderedNothingReportsDidBecomeEmpty() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.reportRendered(0)
        await mainQueueTurn()

        #expect(delegate.events == [.empty])
        #expect(block.bed.failureReporter.reported.isEmpty)
    }

    @Test("Delegate assigned after an empty outcome still hears didBecomeEmpty")
    func lateDelegateHearsEmpty() async {
        let block = BlockFixture(resolution: .empty)
        block.attachToWindow()
        await mainQueueTurn()

        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        await mainQueueTurn()

        #expect(delegate.events == [.empty])
    }

    @Test("Empty after a failure is a new outcome and is delivered")
    func emptyAfterFailureIsDelivered() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        block.page?.failLoad()
        await mainQueueTurn()
        block.bed.resolver.resolution = .empty
        block.bed.announceNewConfig()
        await mainQueueTurn()

        #expect(delegate.events == [.failed(.networkError), .empty])
    }

    @Test("A broken winner reports didFail(internalError) and honours the error view")
    func brokenWinnerFailsAsInternalError() async {
        let block = BlockFixture(resolution: .failure(.broken))
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        let errorView = UIView()
        block.view.errorView = errorView

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events == [.failed(.internalError)])
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains(errorView))
        #expect(block.bed.failureReporter.reasons == [.unknownError])
        #expect(block.bed.pageFactory.pages.isEmpty)
    }

    @Test("A block the SDK has no config for fails as networkError at once and shows the error view")
    func unavailableConfigFailsAsNetworkError() async {
        let block = BlockFixture(resolution: .configUnavailable)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        let errorView = UIView()
        block.view.errorView = errorView

        block.attachToWindow()
        await mainQueueTurn()

        #expect(delegate.events == [.failed(.networkError)])
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains(errorView))
        #expect(block.bed.failureReporter.unansweredWaits.count == 1)
        #expect(block.bed.failureReporter.reported.isEmpty)
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

        #expect(delegate.events == [.failed(.networkError)])
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

        #expect(delegate.events == [.failed(.networkError)])
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

        #expect(first.events == [.failed(.networkError)])
        #expect(second.events == [.failed(.networkError)])
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

        #expect(delegate.events == [.failed(.networkError)])
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

        #expect(delegate.events == [.loaded, .failed(.networkError)])
    }

    // MARK: - Presentation for the SwiftUI wrapper

    @Test("Every change is reported to the wrapper")
    func everyChangeIsReportedToTheWrapper() {
        let block = BlockFixture()
        block.attachToWindow()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.page?.reportRendered(1)
        block.bed.resolver.resolution = .empty
        block.bed.announceNewConfig()

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
        #expect(delegate.events == [.failed(.networkError)])
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
        #expect(delegate.events == [.failed(.networkError), .loaded])
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

    // MARK: - The place name

    @Test("A place name with surrounding whitespace is normalized at the block's boundary")
    func paddedPlaceNameIsNormalized() {
        let bed = EmbeddedBlockTestBed()
        let factory = EmbeddedBlockContentProviderFactoryMock(provider: bed.provider)
        let memory = EmbeddedBlockPlaceMemoryMock()
        // The container is process-global and the mode swap rebuilds it: save and restore both.
        let savedBuilder = MBInject.buildTestContainer
        let savedMode = MBInject.mode
        defer {
            MBInject.buildTestContainer = savedBuilder
            MBInject.mode = savedMode
        }
        MBInject.buildTestContainer = {
            let container = MBContainer()
            container.register(EmbeddedBlockContentProviderMaking.self) { factory }
            container.register(EmbeddedBlockPlaceRemembering.self) { memory }
            return container
        }
        MBInject.mode = .test

        let view = MindboxEmbeddedBlockView(placeSystemName: "  stories \n", height: 120)

        #expect(view.placeSystemName == "stories")
        #expect(factory.requestedPlaces == ["stories"])
        // The memory is keyed by the same normalized name, or a padded name would never find its record.
        #expect(memory.askedPlaces == ["stories"])
    }

    @Test("Only the surrounding whitespace goes, the name itself is kept as it is",
          arguments: [("stories", "stories"),
                      (" stories ", "stories"),
                      ("\tstories\n", "stories"),
                      ("my place", "my place"),
                      ("Stories", "Stories"),
                      ("   ", "")])
    func placeNameNormalizationKeepsTheName(given: String, expected: String) {
        #expect(MindboxEmbeddedBlockView.normalizedPlaceSystemName(given) == expected)
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
        #expect(delegate.events == [.failed(.internalError)])
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
        #expect(delegate.events == [.failed(.internalError)])
    }

    @Test("A block the SDK never answered fails as networkError and shows the error view")
    func neverAnsweredBlockFailsAsNoResponse() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        let errorView = UIView()
        block.view.errorView = errorView
        block.bed.resolver.isDeferred = true
        block.attachToWindow()
        await mainQueueTurn()

        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains(errorView))
        #expect(delegate.events == [.failed(.networkError)])
        #expect(block.bed.failureReporter.unansweredWaits == [block.waitBudgetBed.duration])
        #expect(block.bed.failureReporter.reported.isEmpty)
    }

    @Test("A block the SDK never answered collapses without an error view")
    func neverAnsweredBlockCollapsesWithoutErrorView() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.bed.resolver.isDeferred = true
        block.attachToWindow()
        await mainQueueTurn()

        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed(.networkError)])
    }

    @Test("A different failure reason on a silent retry is not re-delivered")
    func differentReasonOnSilentRetryIsNotRedelivered() async {
        let block = BlockFixture()
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()
        block.page?.failLoad()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()
        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events == [.failed(.networkError)])
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
        #expect(delegate.events == [.failed(.internalError)])
        #expect(block.bed.failureReporter.reasons == [.presentationFailed])
        #expect(block.bed.failureReporter.unansweredWaits.isEmpty)
    }

    @Test("A delayed answer stands the wait budget down and keeps the placeholder")
    func delayedAnswerStandsTheBudgetDown() async {
        let block = BlockFixture(resolution: .content(.delayed()))
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        #expect(!block.waitBudgetBed.budget.isRunning)
        #expect(block.view.intrinsicContentSize.height == 120)

        block.expireTimeout()
        await mainQueueTurn()

        #expect(delegate.events.isEmpty)
        #expect(block.bed.failureReporter.unansweredWaits.isEmpty)
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

    @Test("A block waits the answer timeout for its answer and the page's own budget for the page")
    func waitBudgetFollowsTheLoadingPhase() {
        let awaitingAnswer = OwnBudgetBlockFixture(timeout: 5)
        awaitingAnswer.bed.resolver.isDeferred = true
        awaitingAnswer.attachToWindow()

        #expect(awaitingAnswer.scheduler.lastDelay == 5)
        awaitingAnswer.scheduler.fireAll()
        #expect(awaitingAnswer.view.intrinsicContentSize.height == 0)

        let withPage = OwnBudgetBlockFixture(timeout: 5)
        withPage.attachToWindow()

        #expect(withPage.scheduler.lastDelay == 7)
        #expect(withPage.view.intrinsicContentSize.height == 120)
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
        #expect(delegate.events.last == .failed(.internalError))
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

        #expect(delegate.events == [.failed(.internalError)])
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

    // MARK: - Loading strategy

    @Test("The first look follows the strategy and the place's memory",
          arguments: [
              (MindboxEmbeddedBlockLoadingStrategy.placeholder, false, MindboxEmbeddedBlockAppearance.placeholder),
              (.placeholder, true, .placeholder),
              (.hidden, false, .collapsed),
              (.hidden, true, .collapsed),
              (.automatic, false, .collapsed),
              (.automatic, true, .placeholder)
          ])
    func initialAppearanceFollowsTheStrategyAndTheMemory(strategy: MindboxEmbeddedBlockLoadingStrategy,
                                                         hasShownBefore: Bool,
                                                         expected: MindboxEmbeddedBlockAppearance) {
        #expect(MindboxEmbeddedBlockView.initialAppearance(for: strategy, hasShownContentBefore: hasShownBefore) == expected)
    }

    @Test("A hidden block starts collapsed and reserves no space")
    func hiddenBlockStartsCollapsed() {
        let block = BlockFixture(loadingStrategy: .hidden)
        let appearance = EmbeddedBlockAppearanceSpy()

        block.view.setAppearanceObserver { appearance.record($0) }

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(appearance.values == [.collapsed])
    }

    @Test("A placeholder block starts with the shimmer whatever the place remembers", arguments: [false, true])
    func placeholderBlockStartsWithTheShimmer(hasShownBefore: Bool) {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: hasShownBefore ? ["block-id"] : [])
        let block = BlockFixture(loadingStrategy: .placeholder, memory: memory)

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    @Test("A hidden block starts collapsed whatever the place remembers", arguments: [false, true])
    func hiddenBlockIgnoresTheMemory(hasShownBefore: Bool) {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: hasShownBefore ? ["block-id"] : [])
        let block = BlockFixture(loadingStrategy: .hidden, memory: memory)

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
    }

    @Test("An automatic block starts hidden where nothing was shown and with a placeholder where content was",
          arguments: [(false, CGFloat(0)), (true, CGFloat(120))])
    func automaticBlockFollowsTheMemory(hasShownBefore: Bool, height: CGFloat) {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: hasShownBefore ? ["block-id"] : [])
        let block = BlockFixture(loadingStrategy: .automatic, memory: memory)

        #expect(block.view.intrinsicContentSize.height == height)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView } == hasShownBefore)
    }

    @Test("A hidden block's custom placeholder is never shown")
    func hiddenBlockShowsNoCustomPlaceholder() {
        let block = BlockFixture(loadingStrategy: .hidden)
        let placeholder = UIView()

        block.view.placeholderView = placeholder
        block.attachToWindow()

        #expect(placeholder.superview == nil)
        #expect(block.view.intrinsicContentSize.height == 0)
    }

    @Test("A hidden block takes its height when its content is shown and reports didLoad")
    func hiddenBlockExpandsOnContent() async throws {
        let block = BlockFixture(loadingStrategy: .hidden)
        let delegate = EmbeddedBlockViewDelegateMock()
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.delegate = delegate
        block.attachToWindow()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.page?.reportRendered(2)
        await mainQueueTurn()

        let page = try #require(block.page)
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(page.view.superview === block.view)
        #expect(appearance.values == [.collapsed, .content])
        #expect(delegate.events == [.loaded])
    }

    @Test("A hidden block stays collapsed on an empty place and reports it")
    func hiddenBlockStaysCollapsedOnEmpty() async {
        let block = BlockFixture(resolution: .empty, loadingStrategy: .hidden)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.attachToWindow()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.empty])
    }

    /// Ten hidden places and one network failure must not become ten error screens: the error view is
    /// for a block that already took its space. The host still hears about the failure.
    @Test("A hidden block stays collapsed on a failure even with an error view, and still reports it")
    func hiddenBlockIgnoresTheErrorView() async {
        let block = BlockFixture(loadingStrategy: .hidden)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.view.errorView = UIView()
        block.attachToWindow()

        block.page?.failLoad()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed(.networkError)])
    }

    @Test("A hidden block the SDK never answered stays collapsed with an error view set")
    func hiddenBlockNeverAnsweredStaysCollapsed() async {
        let block = BlockFixture(loadingStrategy: .hidden)
        let delegate = EmbeddedBlockViewDelegateMock()
        block.view.delegate = delegate
        block.view.errorView = UIView()
        block.bed.resolver.isDeferred = true
        block.attachToWindow()

        block.expireTimeout()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
        #expect(delegate.events == [.failed(.networkError)])
    }

    @Test("A hidden block that was shown and then fails shows the error view: it already took its space")
    func hiddenBlockShownThenFailedShowsTheErrorView() async {
        let block = BlockFixture(loadingStrategy: .hidden)
        let errorView = UIView()
        block.view.errorView = errorView
        block.attachToWindow()
        block.page?.reportRendered(1)
        await mainQueueTurn()

        block.page?.failLoad()
        await mainQueueTurn()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains(errorView))
    }

    @Test("A hidden block that failed is revealed only by content on a silent retry")
    func hiddenBlockRetryRevealsOnlyWithContent() async {
        let block = BlockFixture(loadingStrategy: .hidden)
        block.attachToWindow()
        block.page?.failLoad()
        await mainQueueTurn()

        block.removeFromWindow()
        block.attachToWindow()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)

        block.page?.reportRendered(1)

        #expect(block.view.intrinsicContentSize.height == 120)
    }

    @Test("Reload keeps a hidden block collapsed until content, even after content was shown")
    func reloadKeepsAHiddenBlockCollapsed() {
        let block = BlockFixture(loadingStrategy: .hidden)
        block.attachToWindow()
        block.page?.reportRendered(1)
        let appearance = EmbeddedBlockAppearanceSpy()
        block.view.setAppearanceObserver { appearance.record($0) }

        block.view.reload()

        #expect(appearance.values == [.content, .collapsed])
        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)

        block.page?.reportRendered(1)

        #expect(appearance.last == .content)
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    @Test("Reload of an automatic block shows the placeholder once the place is remembered")
    func reloadOfAnAutomaticBlockFollowsTheMemory() {
        let block = BlockFixture(loadingStrategy: .automatic)
        block.attachToWindow()
        #expect(block.view.intrinsicContentSize.height == 0)
        block.page?.reportRendered(1)

        block.view.reload()

        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    @Test("Reload of an automatic block after an empty answer keeps it hidden")
    func reloadOfAnAutomaticBlockAfterEmptyKeepsItHidden() async {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: ["block-id"])
        let block = BlockFixture(resolution: .empty, loadingStrategy: .automatic, memory: memory)
        block.attachToWindow()
        await mainQueueTurn()
        #expect(block.view.intrinsicContentSize.height == 0)

        block.view.reload()

        #expect(block.view.intrinsicContentSize.height == 0)
        #expect(block.view.subviews.isEmpty)
    }

    // MARK: - Place memory

    @Test("Shown content is remembered at the place, whatever the strategy",
          arguments: [MindboxEmbeddedBlockLoadingStrategy.automatic, .placeholder, .hidden])
    func shownContentIsRemembered(strategy: MindboxEmbeddedBlockLoadingStrategy) {
        let block = BlockFixture(loadingStrategy: strategy)
        block.attachToWindow()

        block.page?.reportRendered(1)

        #expect(block.memory.shownPlaces == ["block-id"])
    }

    @Test("Content is remembered when it is shown, not when it merely resolved")
    func contentIsRememberedOnShowOnly() {
        let block = BlockFixture()
        block.attachToWindow()

        #expect(block.memory.remembered.isEmpty)
    }

    @Test("An empty place is forgotten")
    func emptyPlaceIsForgotten() {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: ["block-id"])
        let block = BlockFixture(resolution: .empty, memory: memory)

        block.attachToWindow()

        #expect(memory.shownPlaces.isEmpty)
        #expect(memory.forgotten == ["block-id"])
    }

    @Test("A page that rendered nothing forgets the place")
    func pageThatRenderedNothingForgetsThePlace() {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: ["block-id"])
        let block = BlockFixture(memory: memory)
        block.attachToWindow()

        block.page?.reportRendered(0)

        #expect(memory.shownPlaces.isEmpty)
    }

    @Test("A failure leaves the memory as it is", arguments: [true, false])
    func failureLeavesTheMemoryAlone(hasShownBefore: Bool) {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: hasShownBefore ? ["block-id"] : [])
        let block = BlockFixture(memory: memory)
        block.attachToWindow()

        block.page?.failLoad()

        #expect(memory.hasShownContent(at: "block-id") == hasShownBefore)
        #expect(memory.forgotten.isEmpty)
        #expect(memory.remembered.isEmpty)
    }

    @Test("A block the SDK never answered leaves the memory as it is")
    func neverAnsweredBlockLeavesTheMemoryAlone() {
        let memory = EmbeddedBlockPlaceMemoryMock(shownPlaces: ["block-id"])
        let block = BlockFixture(memory: memory)
        block.bed.resolver.isDeferred = true
        block.attachToWindow()

        block.expireTimeout()

        #expect(memory.shownPlaces == ["block-id"])
        #expect(memory.forgotten.isEmpty)
    }

    @Test("A place remembered on one launch gives the automatic block a placeholder on the next")
    func memorySurvivesToTheNextLaunch() {
        let memory = EmbeddedBlockPlaceMemoryMock()
        let firstLaunch = BlockFixture(loadingStrategy: .automatic, memory: memory)
        firstLaunch.attachToWindow()
        firstLaunch.page?.reportRendered(1)

        let nextLaunch = BlockFixture(loadingStrategy: .automatic, memory: memory)

        #expect(nextLaunch.view.intrinsicContentSize.height == 120)
        #expect(nextLaunch.view.subviews.contains { $0 is EmbeddedBlockShimmerView })
    }

    // MARK: - Reveal animation

    @Test("Content replacing the placeholder fades in")
    func contentFadesInOverThePlaceholder() {
        let block = BlockFixture()
        block.attachToWindow()

        block.page?.reportRendered(1)

        #expect(block.reveal.runs == [Constants.EmbeddedBlock.revealAnimationDuration])
    }

    @Test("A hidden block grows to its height with animation when its content arrives")
    func hiddenBlockGrowsWithAnimation() {
        let block = BlockFixture(loadingStrategy: .hidden)
        block.attachToWindow()

        block.page?.reportRendered(1)

        // The fade of the content and the growth of the height.
        #expect(block.reveal.runs.count == 2)
        #expect(block.view.intrinsicContentSize.height == 120)
    }

    @Test("A wrapper that lays the block out gets the fade only: the height is its own to animate")
    func wrapperLaidOutBlockGetsTheFadeOnly() {
        let block = BlockFixture(loadingStrategy: .hidden)
        block.view.setAppearanceObserver { _ in }
        block.attachToWindow()

        block.page?.reportRendered(1)

        #expect(block.reveal.runs.count == 1)
    }

    @Test("Content shown again on a return is not animated again")
    func returningContentIsNotAnimatedAgain() {
        let block = BlockFixture()
        block.attachToWindow()
        block.page?.reportRendered(1)
        let runsAfterTheReveal = block.reveal.runs.count

        block.removeFromWindow()
        block.attachToWindow()

        #expect(block.reveal.runs.count == runsAfterTheReveal)
    }

    @Test("Neither a collapse nor an error screen is animated")
    func collapseAndErrorScreenAreNotAnimated() {
        let block = BlockFixture()
        block.view.errorView = UIView()
        block.attachToWindow()

        block.page?.failLoad()
        block.view.errorView = nil

        #expect(block.reveal.runs.isEmpty)
    }

    @Test("With the animation turned off the content lands at once")
    func animationOffRevealsAtOnce() {
        let block = BlockFixture(loadingStrategy: .hidden, animatesReveal: false)
        block.attachToWindow()

        block.page?.reportRendered(1)

        #expect(block.reveal.runs.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)
        #expect(block.view.subviews.count == 1)
    }

    @Test("Reduce Motion turns the reveal animation off")
    func reduceMotionTurnsTheAnimationOff() {
        let block = BlockFixture(loadingStrategy: .hidden)
        block.reveal.isReduceMotionEnabled = true
        block.attachToWindow()

        block.page?.reportRendered(1)

        #expect(block.reveal.runs.isEmpty)
        #expect(block.view.intrinsicContentSize.height == 120)
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

    /// The place's memory across launches: a fixture built over the same mock is the block's next launch.
    let memory: EmbeddedBlockPlaceMemoryMock

    /// The SDK's reveal animation, run on the spot and counted.
    let reveal: EmbeddedBlockRevealAnimationSpy

    let view: MindboxEmbeddedBlockView

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    var page: EmbeddedBlockPageMock? { bed.page }

    /// `placeholder` by default: most of the suite is about what happens after the block took its
    /// space, and that is the look every block used to start with.
    init(height: CGFloat = 120,
         resolution: EmbeddedBlockResolution = .content(.stub),
         loadingStrategy: MindboxEmbeddedBlockLoadingStrategy = .placeholder,
         animatesReveal: Bool = true,
         memory: EmbeddedBlockPlaceMemoryMock = EmbeddedBlockPlaceMemoryMock()) {
        let bed = EmbeddedBlockTestBed(resolution: resolution)
        let waitBudgetBed = EmbeddedBlockWaitBudgetBed()
        let reveal = EmbeddedBlockRevealAnimationSpy()
        self.bed = bed
        self.waitBudgetBed = waitBudgetBed
        self.memory = memory
        self.reveal = reveal
        self.view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                             height: height,
                                             contentProvider: bed.provider,
                                             placeMemory: memory,
                                             loadingStrategy: loadingStrategy,
                                             animatesReveal: animatesReveal,
                                             revealAnimation: reveal.animation,
                                             makeWaitBudget: { _, _ in waitBudgetBed.budget })
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

/// A block on the waiting budget the container builds for itself — its own switch between the answer
/// timeout and the page's budget — counted down by a test scheduler.
@MainActor
private final class OwnBudgetBlockFixture {

    let bed: EmbeddedBlockTestBed

    let scheduler: TestScheduler

    let view: MindboxEmbeddedBlockView

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    init(timeout: TimeInterval) {
        let bed = EmbeddedBlockTestBed()
        let scheduler = TestScheduler()
        self.bed = bed
        self.scheduler = scheduler
        self.view = MindboxEmbeddedBlockView(placeSystemName: "block-id",
                                             height: 120,
                                             contentProvider: bed.provider,
                                             placeMemory: EmbeddedBlockPlaceMemoryMock(),
                                             loadingStrategy: .placeholder,
                                             timeout: timeout,
                                             makeWaitBudget: { place, duration in
                                                 EmbeddedBlockWaitBudget(placeSystemName: place,
                                                                         duration: duration,
                                                                         now: { bed.clock.now },
                                                                         notificationCenter: bed.center,
                                                                         schedule: { scheduler.schedule($0, $1) })
                                             })
    }

    func attachToWindow() {
        window.addSubview(view)
    }
}
