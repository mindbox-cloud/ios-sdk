//
//  EmbeddedBlockWebViewProviderTests.swift
//  MindboxTests
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import QuartzCore
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block web view provider", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWebViewProviderTests {

    // MARK: - Loading

    @Test("Start resolves the id and loads the resolved content")
    func startResolvesAndLoads() {
        let bed = EmbeddedBlockTestBed(placeSystemName: "promo")
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(bed.resolver.resolvedPlaces == ["promo"])
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

    @Test("A page that drew something makes the content available")
    func pageReadyMakesContentAvailable() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.reportRendered(1)

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

    @Test("A report without a readable count is a failure")
    func reportWithoutCountIsFailure() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.reportRenderedWithoutCount()

        #expect(states.last == .failed(.internalError))
        #expect(bed.provider.contentView == nil)
    }

    @Test("A page that drew nothing collapses the block")
    func pageEmptyCollapsesTheBlock() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.reportRendered(0)

        #expect(states == [.empty])
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - The place's slot

    @Test("A block that started took the place's slot and keeps it while loading")
    func loadingBlockKeepsTheSlot() {
        let bed = EmbeddedBlockTestBed(placeSystemName: "promo")

        bed.provider.start()

        #expect(bed.budget.reservedOwners == [.place("promo")])
        #expect(bed.budget.releases.isEmpty)
    }

    @Test("A paused block with content parked for its return still holds its attempt")
    func pausedBlockWithParkedContentHoldsItsAttempt() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()
        bed.provider.stop()

        bed.provider.apply(bed.answer(.content(.stub)))

        #expect(bed.provider.holdsAnAttempt)
    }

    @Test("A page that failed to load gives the place's slot back")
    func failedPageGivesTheSlotBack() {
        let bed = EmbeddedBlockTestBed(placeSystemName: "promo")

        bed.provider.start()
        bed.page?.failLoad()

        #expect(bed.budget.releases == [.place("promo")])
    }

    @Test("A page that drew nothing gives the place's slot back")
    func emptyPageGivesTheSlotBack() {
        let bed = EmbeddedBlockTestBed(placeSystemName: "promo")

        bed.provider.start()
        bed.page?.reportRendered(0)

        #expect(bed.budget.releases == [.place("promo")])
    }

    @Test("A block leaving the screen keeps the place's slot")
    func stoppedBlockKeepsTheSlot() {
        let bed = EmbeddedBlockTestBed(placeSystemName: "promo")

        bed.provider.start()
        bed.provider.stop()

        #expect(bed.budget.releases.isEmpty)
    }

    @Test("A torn-down or abandoned block gives the place's slot back", arguments: [true, false])
    func goneBlockGivesTheSlotBack(isTornDown: Bool) {
        let bed = EmbeddedBlockTestBed(placeSystemName: "promo")

        bed.provider.start()
        if isTornDown {
            bed.provider.teardown()
        } else {
            bed.provider.abandonAttempt()
        }

        #expect(bed.budget.releases == [.place("promo")])
    }

    // MARK: - Accounting for the show

    @Test("A block that drew its page hands the show to the accounting")
    func renderedBlockIsAccountedFor() throws {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)

        let show = try #require(bed.accounting.shows.first)
        #expect(bed.accounting.shows.count == 1)
        #expect(show.inAppId == EmbeddedBlockWebContent.stub.inAppId)
        #expect(show.frequency == EmbeddedBlockWebContent.counted().frequency)
        #expect(show.tags == EmbeddedBlockWebContent.stub.tags)
    }

    @Test("A show is accounted from the content the block was given, whatever the place resolves to later")
    func showIsAccountedFromTheSnapshot() throws {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))
        bed.provider.start()

        bed.resolver.resolution = .content(.other)
        bed.page?.reportRendered(3)

        let show = try #require(bed.accounting.shows.first)
        #expect(show.inAppId == EmbeddedBlockWebContent.stub.inAppId)
        #expect(show.frequency == EmbeddedBlockWebContent.counted().frequency)
        #expect(show.tags == EmbeddedBlockWebContent.stub.tags)
    }

    @Test("Nothing drawn, nothing accounted")
    func pageWithoutContentIsNotAccounted() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(0)

        #expect(bed.accounting.shows.isEmpty)
    }

    @Test("A negative count is a failure, not an empty block")
    func negativeCountIsFailure() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.reportRendered(-1)

        #expect(states.last == .failed(.internalError))
        #expect(bed.accounting.shows.isEmpty)
        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    @Test("A page that failed to load is not accounted")
    func failedPageIsNotAccounted() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.failLoad()

        #expect(bed.accounting.shows.isEmpty)
    }

    @Test("An unreadable report is a failure, not a show")
    func unreadableReportIsNoShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRenderedWithoutCount()

        #expect(bed.accounting.shows.isEmpty)
        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    @Test("A page reporting itself again is accounted once")
    func repeatedReportIsAccountedOnce() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.page?.reportRendered(4)

        #expect(bed.accounting.shows.count == 1)
    }

    @Test("A page rebuilt for the same content hands its show to the accounting again")
    func rebuiltPageIsHandedToAccountingAgain() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))
        bed.provider.start()
        bed.page?.reportRendered(3)

        bed.provider.reload()
        bed.page?.reportRendered(3)

        #expect(bed.accounting.shows.count == 2)
    }

    @Test("A block show is accounted at the block's place")
    func showIsAccountedAtThePlace() {
        let bed = EmbeddedBlockTestBed(placeSystemName: "the-place")

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.accounting.places == ["the-place"])
    }

    @Test("A page shown again on return is accounted once")
    func returningBlockIsAccountedOnce() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.provider.stop()
        bed.provider.start()

        #expect(bed.accounting.shows.count == 1)
    }

    @Test("A page that drew off screen is not accounted when another in-app waits for the block's return")
    func offScreenRenderReplacedBeforeTheReturnIsNotAccounted() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))
        bed.provider.start()
        bed.provider.stop()
        bed.page?.reportRendered(3)
        bed.resolver.resolution = .content(.other)
        bed.provider.apply(bed.answer(.content(.other)))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(bed.accounting.shows.isEmpty)
        #expect(states == [.loading])
        #expect(bed.pageFactory.contents.last == .other)
        #expect(bed.pageFactory.pages.count == 2)
    }

    @Test("A page rebuilt for another in-app hands its show to the accounting again")
    func pageForAnotherInappIsHandedToAccountingAgain() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.resolver.resolution = .content(.other)
        bed.announceNewConfig()
        bed.page?.reportRendered(1)

        #expect(bed.accounting.shownIds == [EmbeddedBlockWebContent.stub.inAppId,
                                            EmbeddedBlockWebContent.other.inAppId])
    }

    @Test("The block's timeToDisplay is the selection's processing plus the page's rendering")
    func timeToDisplayAddsProcessingToRendering() throws {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.processingDuration = 2

        bed.provider.start()
        bed.clock.advance(0.75)
        bed.page?.reportRendered(3)

        let show = try #require(bed.accounting.shows.first)
        #expect(show.timeToDisplay == 2.75)
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

        #expect(states == [.loading, .failed(.networkError)])
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

    // MARK: - Reporting a failure

    @Test("A page that failed to load is reported")
    func loadFailureIsReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()

        #expect(bed.failureReporter.reasons == [.webviewLoadFailed])
        #expect(bed.failureReporter.reported.first?.inAppId == EmbeddedBlockWebContent.stub.inAppId)
        #expect(bed.failureReporter.reported.first?.tags == EmbeddedBlockWebContent.stub.tags)
    }

    @Test("An unreadable report is reported as a presentation failure")
    func unreadableReportIsReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRenderedWithoutCount()

        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    @Test("A page that ran out of patience is reported")
    func timedOutPageIsReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.provider.failSilentPage()

        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    @Test("A delayed answer keeps the block loading and tells the container")
    func delayedAnswerKeepsTheBlockLoading() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        var delayedCalls = 0
        var states: [EmbeddedBlockState] = []
        bed.provider.onContentDelayed = { delayedCalls += 1 }
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        bed.provider.contentIsDelayed()

        #expect(bed.provider.isAwaitingDelayedContent)
        #expect(delayedCalls == 1)
        #expect(states == [.loading])

        bed.provider.apply(bed.answer(.content(.stub)))

        #expect(!bed.provider.isAwaitingDelayedContent)
    }

    @Test("A delay announced while the page is loading leaves the page its own budget")
    func delayAnnouncedWhileThePageLoadsIsIgnored() {
        let bed = EmbeddedBlockTestBed()
        var delayedCalls = 0
        bed.provider.onContentDelayed = { delayedCalls += 1 }
        bed.provider.start()

        bed.provider.contentIsDelayed()

        #expect(!bed.provider.isAwaitingDelayedContent)
        #expect(delayedCalls == 0)
    }

    @Test("A block the SDK never answered reports one failure without an in-app")
    func unansweredBlockReportsOneUnattributedFailure() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.failUnanswered(waited: 30)

        #expect(bed.failureReporter.unansweredWaits == [30])
        #expect(bed.failureReporter.reported.isEmpty)
    }

    @Test("A second unanswered wait at the same place in one session reports nothing")
    func secondUnansweredWaitIsSilent() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.failUnanswered(waited: 30)
        bed.provider.failUnanswered(waited: 30)

        #expect(bed.failureReporter.unansweredWaits.count == 1)
    }

    @Test("Another place's unanswered wait is reported on its own")
    func anotherPlacesUnansweredWaitIsReported() {
        let first = EmbeddedBlockTestBed(placeSystemName: "first-place")
        let second = EmbeddedBlockTestBed(placeSystemName: "second-place")

        first.provider.failUnanswered(waited: 30)
        second.provider.failUnanswered(waited: 30)

        #expect(first.failureReporter.unansweredWaits.count == 1)
        #expect(second.failureReporter.unansweredWaits.count == 1)
    }

    @Test("An empty place reports nothing")
    func emptyPlaceReportsNothing() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()

        bed.provider.failSilentPage()

        #expect(bed.failureReporter.reported.isEmpty)
    }

    @Test("A silent page fails the block as internalError")
    func silentPageFailsAsContentFailed() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        bed.provider.failSilentPage()

        #expect(states == [.loading, .failed(.internalError)])
        #expect(bed.provider.contentView == nil)
        #expect(bed.page?.cancelCount == 1)
    }

    @Test("An unanswered block fails as networkError every time, whatever the analytics already heard")
    func unansweredBlockFailsAsNoResponseEveryTime() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.provider.failUnanswered(waited: 30)
        bed.provider.start()
        bed.provider.failUnanswered(waited: 30)

        #expect(states == [.loading, .failed(.networkError), .loading, .failed(.networkError)])
        #expect(bed.failureReporter.unansweredWaits == [30])
    }

    @Test("A config arriving after an unanswered wait does not revive the block until it is back on screen")
    func configAfterUnansweredWaitWaitsForTheNextAppearance() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()
        bed.provider.failUnanswered(waited: 30)

        // The SDK answers late, then a config lands: neither reaches a block that gave up.
        bed.resolver.flush()
        bed.announceNewConfig()

        #expect(states == [.loading, .failed(.networkError)])
        #expect(bed.pageFactory.pages.isEmpty)
        #expect(bed.resolver.resolveCount == 1)

        bed.provider.start()
        bed.resolver.flush()
        bed.page?.reportRendered(1)

        #expect(states == [.loading, .failed(.networkError), .loading, .ready])
        #expect(bed.provider.contentView != nil)
    }

    @Test("A broken winner fails the block as internalError and reports unknown_error")
    func brokenWinnerFailsAsInternalError() {
        let bed = EmbeddedBlockTestBed(resolution: .failure(.broken))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading, .failed(.internalError)])
        #expect(bed.pageFactory.pages.isEmpty)
        #expect(bed.provider.contentView == nil)
        #expect(bed.failureReporter.reasons == [.unknownError])
        #expect(bed.failureReporter.reported.first?.inAppId == "broken-inapp-id")
        #expect(bed.failureReporter.reported.first?.tags == ["templateType": "Broken"])
        #expect(bed.failureReporter.reported.first?.details == EmbeddedBlockResolutionFailure.broken.details)
    }

    @Test("The same broken winner asked again is neither re-reported nor re-announced")
    func sameBrokenWinnerAskedAgainIsSilent() {
        let bed = EmbeddedBlockTestBed(resolution: .failure(.broken))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        bed.announceNewConfig()

        #expect(states == [.loading, .failed(.internalError)])
        #expect(bed.failureReporter.reasons == [.unknownError])
    }

    @Test("A broken winner arriving while the block is paused is reported at once and applied on return")
    func brokenWinnerWhilePausedIsAppliedOnReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()
        bed.provider.stop()

        bed.resolver.resolution = .failure(.broken)
        bed.resolver.flush()

        #expect(states == [.loading])
        #expect(bed.failureReporter.reasons == [.unknownError])

        bed.provider.start()

        #expect(states == [.loading, .failed(.internalError)])
        #expect(bed.failureReporter.reasons == [.unknownError])
    }

    @Test("A broken winner replacing shown content drops the page")
    func brokenWinnerDropsTheShownPage() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.resolver.resolution = .failure(.broken)
        _ = bed.announceOperation()

        #expect(states == [.loading, .ready, .failed(.internalError)])
        #expect(bed.provider.contentView == nil)
        #expect(bed.pageFactory.pages.first?.cancelCount == 1)
    }

    @Test("An unavailable config fails the block as networkError and reports the unanswered wait")
    func unavailableConfigFailsAsNetworkError() {
        let bed = EmbeddedBlockTestBed(resolution: .configUnavailable)
        bed.resolver.processingDuration = 1.5
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading, .failed(.networkError)])
        #expect(bed.pageFactory.pages.isEmpty)
        #expect(bed.provider.contentView == nil)
        #expect(bed.failureReporter.unansweredWaits == [1.5])
        #expect(bed.failureReporter.reported.isEmpty)
    }

    @Test("A place the pass could not check fails the block as networkError without a report of its own")
    func uncheckedPlaceFailsAsNetworkError() {
        let bed = EmbeddedBlockTestBed(resolution: .targetingUnavailable)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading, .failed(.networkError)])
        #expect(bed.pageFactory.pages.isEmpty)
        #expect(bed.provider.contentView == nil)
        // The pass already reported the failed fetch per candidate it cut.
        #expect(bed.failureReporter.reported.isEmpty)
        #expect(bed.failureReporter.unansweredWaits.isEmpty)
    }

    @Test("An unavailable config asked again in the session fails again but reports once")
    func unavailableConfigAskedAgainReportsOnce() {
        let bed = EmbeddedBlockTestBed(resolution: .configUnavailable)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        bed.provider.stop()
        bed.provider.start()

        #expect(states == [.loading, .failed(.networkError), .loading, .failed(.networkError)])
        #expect(bed.failureReporter.unansweredWaits.count == 1)
    }

    @Test("A config arriving after an unavailable one revives the block")
    func configArrivingAfterUnavailableRevivesTheBlock() {
        let bed = EmbeddedBlockTestBed(resolution: .configUnavailable)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        bed.resolver.resolution = .content(.stub)
        bed.announceNewConfig()
        bed.page?.reportRendered(1)

        #expect(states == [.loading, .failed(.networkError), .loading, .ready])
        #expect(bed.provider.contentView != nil)
    }

    @Test("A page that drew nothing reports nothing")
    func emptyPageReportsNothing() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRendered(0)

        #expect(bed.failureReporter.reported.isEmpty)
    }

    // MARK: - A new config

    @Test("The same page with new data is told about it")
    func samePageIsToldAboutNewData() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        let fresh = EmbeddedBlockWebContent(inAppId: EmbeddedBlockWebContent.stub.inAppId,
                                            baseUrl: EmbeddedBlockWebContent.stub.baseUrl,
                                            contentUrl: EmbeddedBlockWebContent.stub.contentUrl,
                                            frequency: EmbeddedBlockWebContent.stub.frequency,
                                            tags: EmbeddedBlockWebContent.stub.tags,
                                            params: ["stories": .array([.string("one")])])
        bed.resolver.resolution = .content(fresh)
        bed.announceNewConfig()

        #expect(bed.page?.initDataPushes == [fresh.params])
        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("A config that changed only the frequency or tags leaves the page alone")
    func metadataOnlyChangeIsNotPushedToThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .content(.counted())
        bed.announceNewConfig()
        bed.page?.reportRendered(0)

        #expect(bed.page?.initDataPushes.isEmpty == true)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(states.isEmpty)
    }

    @Test("A show is accounted with the frequency the config moved to while the page was loading")
    func snapshotFollowsAMetadataOnlyChange() throws {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.resolver.resolution = .content(.counted())
        bed.announceNewConfig()
        bed.page?.reportRendered(1)

        let show = try #require(bed.accounting.shows.first)
        #expect(show.frequency == EmbeddedBlockWebContent.counted().frequency)
        #expect(bed.page?.initDataPushes.isEmpty == true)
    }

    @Test("A config that empties the place drops the page still loading: its late report shows nothing")
    func emptyAnswerWhileLoadingDropsThePage() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()
        let page = bed.page

        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        page?.reportRendered(1)

        #expect(page?.isClosed == true)
        #expect(states == [.loading, .empty])
        #expect(bed.accounting.shows.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    @Test("An empty answer after the page drew nothing drops that page too")
    func emptyAnswerAfterAnEmptyPageDropsIt() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(0)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.apply(bed.answer(.empty))
        bed.page?.reportRendered(1)

        #expect(bed.page?.isClosed == true)
        #expect(states.isEmpty)
        #expect(bed.accounting.shows.isEmpty)
    }

    // MARK: - The data push's confirmation

    @Test("A page that never confirms the data push is rebuilt")
    func silentDataPushRebuildsThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        bed.ackScheduler.fire()

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.pages.last?.loadCount == 1)
    }

    @Test("A confirmed data push keeps the page")
    func confirmedDataPushKeepsThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        bed.page?.confirmInitData()
        bed.ackScheduler.fire()

        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("A stopped block drops the confirmation wait")
    func stoppedBlockDropsTheAckWait() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        bed.provider.stop()
        bed.ackScheduler.fire()

        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("A data push confirmation arriving while paused clears the wait and prevents rebuild on return")
    func dataPushConfirmationWhilePausedClearsTheWait() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()
        #expect(bed.ackScheduler.scheduled.count == 1)

        bed.provider.stop()
        bed.page?.confirmInitData()

        bed.provider.start()

        #expect(bed.ackScheduler.scheduled.count == 1)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.loadCount == 1)
    }

    @Test("The confirmation wait uses the page budget")
    func ackWaitUsesThePageBudget() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        #expect(bed.ackScheduler.scheduled.map(\.delay) == [TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)])
    }

    @Test("Another in-app at the place replaces the page")
    func anotherInappReplacesThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.resolver.resolution = .content(.other)
        bed.announceNewConfig()

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.contents.last == .other)
    }

    @Test("A place an operation dropped collapses the block at once")
    func droppedPlaceCollapsesTheBlock() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .empty
        _ = bed.announceOperation()

        #expect(states == [.empty])
        #expect(bed.provider.contentView == nil)
    }

    @Test("A stopped block is not told about a new config")
    func stoppedBlockIsNotTold() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        let resolvesBefore = bed.resolver.resolveCount

        bed.announceNewConfig()

        #expect(bed.resolver.resolveCount == resolvesBefore)
        #expect(bed.page?.initDataPushes.isEmpty == true)
    }

    @Test("A config landing while the first resolve is in flight is queued, not lost")
    func configDuringFirstResolveIsQueued() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.announceNewConfig()
        #expect(bed.resolver.resolveCount == 1)

        bed.resolver.flush()
        #expect(bed.resolver.resolveCount == 2)
    }

    @Test("An operation during the first resolve is queued together with its trigger")
    func operationDuringFirstResolveKeepsItsTrigger() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        let event = bed.announceOperation()
        #expect(bed.resolver.resolveCount == 1)

        bed.resolver.flush()

        #expect(bed.resolver.resolveCount == 2)
        let carried = bed.resolver.triggers.last ?? nil
        #expect(carried === event)
    }

    @Test("A new config revives a block that had settled as empty")
    func newConfigRevivesAnEmptyBlock() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .content(.stub)
        bed.announceNewConfig()

        #expect(states.contains(.loading))
        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("A new config reloads a block whose page failed to load")
    func newConfigReloadsAFailedPage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()

        bed.announceNewConfig()

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.pages.first?.initDataPushes.isEmpty == true)
    }

    // MARK: - An operation

    @Test("An operation re-resolves the place in its own context")
    func operationReresolvesInItsContext() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        let fresh = EmbeddedBlockWebContent(inAppId: EmbeddedBlockWebContent.stub.inAppId,
                                            baseUrl: EmbeddedBlockWebContent.stub.baseUrl,
                                            contentUrl: EmbeddedBlockWebContent.stub.contentUrl,
                                            frequency: EmbeddedBlockWebContent.stub.frequency,
                                            tags: EmbeddedBlockWebContent.stub.tags,
                                            params: ["stories": .array([.string("one")])])
        bed.resolver.resolution = .content(fresh)
        let event = bed.announceOperation("custom.operation")

        let carried = bed.resolver.triggers.last ?? nil
        #expect(carried === event)
        #expect(bed.page?.initDataPushes.count == 1)
    }

    @Test("The same answer again leaves the healthy page alone")
    func sameAnswerIsDeduplicated() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.announceNewConfig()
        _ = bed.announceOperation()

        #expect(states.isEmpty)
        #expect(bed.page?.initDataPushes.isEmpty == true)
        #expect(bed.pageFactory.pages.count == 1)
    }

    /// A data push cannot revive a collapsed block: the page answers `initDataUpdated` and stays as it
    /// is, so the block would wait for a report that never comes. It is rebuilt instead, like Android.
    @Test("The same answer revives a page that was collapsed by a dropped place, by rebuilding it")
    func sameAnswerRevivesACollapsedPage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.resolver.resolution = .empty
        _ = bed.announceOperation()

        bed.resolver.resolution = .content(.stub)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.announceNewConfig()
        bed.page?.reportRendered(1)

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.pages.first?.initDataPushes.isEmpty == true)
        #expect(states == [.loading, .ready])
    }

    @Test("A block collapsed by its own page is rebuilt for new data, not told about it")
    func collapsedBlockIsRebuiltForNewData() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(0)

        bed.deliverSamePageWithNewData()

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.pages.first?.initDataPushes.isEmpty == true)
    }

    @Test("A shown block is not collapsed by a later report of nothing")
    func shownBlockIgnoresALaterEmptyReport() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(2)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.reportRendered(0)

        #expect(states.isEmpty)
        #expect(bed.provider.contentView != nil)
    }

    /// One show must not carry both `Inapp.Show` and `Inapp.ShowFailure`: the show is already accounted
    /// for when the repeat arrives.
    @Test("A shown block is not failed by a later unreadable report")
    func shownBlockIgnoresALaterUnreadableReport() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(2)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.reportRenderedWithoutCount()

        #expect(bed.failureReporter.reported.isEmpty)
        #expect(bed.accounting.shows.count == 1)
        #expect(states.isEmpty)
    }

    /// The latch closes on drawn content only: a page that reports nothing first and draws later — it was
    /// still waiting for its answer about which in-apps it may draw — is still heard.
    @Test("A page that drew nothing and then drew something is heard")
    func pageThatDrawsAfterReportingNothingIsHeard() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.reportRendered(0)
        bed.page?.reportRendered(2)

        #expect(states == [.empty, .ready])
        #expect(bed.accounting.shownIds == [EmbeddedBlockWebContent.stub.inAppId])
    }

    @Test("A data push lets the page report itself again")
    func dataPushReopensTheReport() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(2)
        bed.deliverSamePageWithNewData()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.reportRendered(0)

        #expect(states == [.empty])
    }

    @Test("An operation revives a block that had settled as empty")
    func operationRevivesAnEmptyBlock() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()

        bed.resolver.resolution = .content(.stub)
        let event = bed.announceOperation()

        #expect(bed.pageFactory.pages.count == 1)
        let carried = bed.resolver.triggers.last ?? nil
        #expect(carried === event)
    }

    @Test("A stopped block ignores operations")
    func stoppedBlockIgnoresOperations() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        let resolvesBefore = bed.resolver.resolveCount

        _ = bed.announceOperation()

        #expect(bed.resolver.resolveCount == resolvesBefore)
    }

    // MARK: - A new session

    @Test("A new session hands a drawn page its data again, equal data included")
    func newSessionRefreshesADrawnPage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.announceNewSession()

        #expect(bed.page?.initDataPushes == [EmbeddedBlockWebContent.stub.params])
        #expect(bed.pageFactory.pages.count == 1)
        #expect(states.isEmpty)
    }

    @Test("The new session's show goes when the page draws its new data, not on the push, its confirmation or another answer")
    func newSessionShowWaitsForTheRedraw() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.announceNewSession()
        bed.page?.confirmInitData()
        bed.announceNewConfig()
        #expect(bed.accounting.sessionEpochs == [first])

        bed.page?.reportRendered(1)

        #expect(bed.accounting.sessionEpochs == [first, first + 1])
        #expect(bed.accounting.shownIds == [EmbeddedBlockWebContent.stub.inAppId, EmbeddedBlockWebContent.stub.inAppId])
    }

    @Test("A session hands its page the data once and shows it once, however many answers it brings")
    func newSessionRefreshesAndShowsOnce() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.announceNewSession()
        bed.page?.confirmInitData()
        bed.page?.reportRendered(1)
        bed.announceNewConfig()
        bed.provider.stop()
        bed.provider.start()

        #expect(bed.page?.initDataPushes.count == 1)
        #expect(bed.accounting.shows.count == 2)
    }

    @Test("A return to the screen within the session hands the page nothing and shows nothing new")
    func returnWithinTheSessionChangesNothing() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.provider.stop()
        bed.provider.start()
        bed.announceNewConfig()

        #expect(bed.page?.initDataPushes.isEmpty == true)
        #expect(bed.accounting.shows.count == 1)
    }

    @Test("A page still loading when the new session lands is told once it has drawn, and shown once it draws again")
    func loadingPageIsRefreshedAfterItDraws() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()

        bed.announceNewSession()
        #expect(bed.page?.initDataPushes.isEmpty == true)

        bed.page?.reportRendered(1)
        #expect(bed.page?.initDataPushes == [EmbeddedBlockWebContent.stub.params])
        #expect(bed.accounting.shows.isEmpty)

        bed.page?.reportRendered(1)
        #expect(bed.accounting.sessionEpochs == [first + 1])
    }

    @Test("A block off screen through the new session is brought up to it on return")
    func blockOffScreenCatchesUpOnReturn() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()

        bed.announceNewSession()
        #expect(bed.page?.initDataPushes.isEmpty == true)

        bed.provider.start()
        bed.page?.reportRendered(1)

        #expect(bed.page?.initDataPushes == [EmbeddedBlockWebContent.stub.params])
        #expect(bed.accounting.sessionEpochs == [first, first + 1])
    }

    @Test("A show that came due in the background goes once the user is back and the session check of the return is over")
    func showDueInTheBackgroundGoesOnReturn() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.enterBackground()
        bed.page?.reportRendered(1)

        bed.returnToApp()
        #expect(bed.accounting.sessionEpochs.isEmpty)

        bed.finishSessionCheck()

        #expect(bed.accounting.sessionEpochs == [first])
    }

    @Test("A page drawn while the user was away, who came back past the session's end, is shown once: in the new session, after it redraws")
    func showDueFromAnExpiredSessionGoesInTheNewOneOnly() {
        let bed = EmbeddedBlockTestBed()
        let tracker = InAppMessagesTrackerSpyMock()
        bed.accounting.accountant = InappShowAccountant(tracker: tracker, budget: bed.budget)
        bed.provider.start()
        bed.enterBackground()
        bed.page?.reportRendered(1)

        bed.returnToApp()
        #expect(tracker.trackViewCallCount == 0)

        bed.expireSession()
        bed.finishSessionCheck()
        #expect(tracker.trackViewCallCount == 0)

        bed.concludeNewSessionDownload()
        #expect(bed.page?.initDataPushes == [EmbeddedBlockWebContent.stub.params])
        bed.page?.reportRendered(1)

        #expect(tracker.trackViewCallCount == 1)
        #expect(bed.accounting.sessionEpochs.last == bed.currentSessionEpoch)
    }

    @Test("A session check that began before the trip to the background does not let the return's show go")
    func sessionCheckFromBeforeTheReturnLetsNothingGo() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.enterBackground()
        bed.page?.reportRendered(1)
        bed.returnToApp()

        bed.finishSessionCheck(startedAt: bed.clock.now - 1)
        #expect(bed.accounting.shows.isEmpty)

        bed.finishSessionCheck()

        #expect(bed.accounting.shows.count == 1)
    }

    @Test("A page that draws while the app is inactive is shown once the app is active again")
    func showDueWhileInactiveGoesOnBecomingActive() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.applicationState = .inactive
        bed.page?.reportRendered(1)
        #expect(bed.accounting.shows.isEmpty)

        bed.becomeActive()

        #expect(bed.accounting.shows.count == 1)
    }

    @Test("A block created after a return, before that return's session check ends, waits for the check like the rest")
    func blockCreatedInTheReturnWindowWaitsForTheCheck() {
        let bed = EmbeddedBlockTestBed()
        bed.enterBackground()
        bed.returnToApp()

        let late = bed.makeProvider(placeSystemName: "late-block")
        late.start()
        bed.page?.reportRendered(1)
        #expect(bed.resolver.resolveCount == 0)
        #expect(bed.accounting.shows.isEmpty)

        bed.finishSessionCheck()
        bed.page?.reportRendered(1)

        #expect(bed.resolver.resolvedPlaces == ["late-block"])
        #expect(bed.accounting.places == ["late-block"])
        withExtendedLifetime(late) {}
    }

    @Test("A block back on screen between a return and the end of its session check meets the session the check leaves: an answer parked in it applies, one of a session that ended is dropped",
          arguments: [false, true])
    func returnToTheScreenInsideTheReturnWaitsForTheCheck(sessionExpired: Bool) {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        bed.provider.apply(bed.answer(.empty))
        bed.resolver.isDeferred = true
        bed.enterBackground()
        bed.returnToApp()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        #expect(states.isEmpty)
        #expect(bed.resolver.resolveCount == 1)

        if sessionExpired {
            bed.expireSession()
        }
        bed.finishSessionCheck(startsNewSession: sessionExpired)

        #expect(states == (sessionExpired ? [.ready] : [.empty]))
        #expect(bed.page?.isClosed == !sessionExpired)
        #expect(bed.resolver.resolveCount == 2)
    }

    @Test("A block that leaves the screen again before the return's session check ends does not start when it ends")
    func blockLeavingInsideTheReturnDoesNotStartAfterIt() {
        let bed = EmbeddedBlockTestBed()
        bed.enterBackground()
        bed.returnToApp()

        bed.provider.start()
        bed.provider.stop()
        bed.finishSessionCheck()

        #expect(bed.resolver.resolveCount == 0)
    }

    @Test("A reload between a return and the end of its session check begins its attempt once the check ends")
    func reloadInsideTheReturnWaitsForTheCheck() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.enterBackground()
        bed.returnToApp()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.reload()
        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.provider.isStartPending)

        bed.finishSessionCheck()

        #expect(bed.resolver.resolveCount == 2)
        #expect(states == [.loading])
        #expect(bed.pageFactory.pages.count == 2)
    }

    @Test("Another page an operation names between a return and the end of its session check is not built from the session the check ends")
    func operationInsideTheReturnBuildsNoPageOfTheEndingSession() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.enterBackground()
        bed.returnToApp()

        bed.resolver.resolution = .content(.other)
        bed.announceOperation()
        #expect(bed.pageFactory.pages.count == 1)

        bed.expireSession()
        bed.finishSessionCheck(startsNewSession: true)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.budget.reservations.map(\.inAppId) == [EmbeddedBlockWebContent.stub.inAppId])

        bed.concludeNewSessionDownload()

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.budget.reservations.map(\.inAppId) == [EmbeddedBlockWebContent.stub.inAppId, EmbeddedBlockWebContent.other.inAppId])
    }

    @Test("A return before the SDK is initialized holds nothing back: no session check follows it")
    func returnBeforeInitializationHoldsNothingBack() {
        let bed = EmbeddedBlockTestBed()
        bed.presenceBed.isSDKInitialized = false
        bed.provider.start()
        bed.enterBackground()
        bed.page?.reportRendered(1)

        bed.returnToApp()

        #expect(bed.accounting.shows.count == 1)
    }

    @Test("A return and the session check that answers it are compared on the monotonic clock the check stamps itself with")
    func returnAndItsCheckShareTheMonotonicClock() {
        let center = NotificationCenter()
        let presence = EmbeddedBlockAppPresence(applicationState: { .active }, isSDKInitialized: { true }, notificationCenter: center)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        let checkStartedBeforeTheReturn = CACurrentMediaTime() - 1
        let checkStartedAfterTheReturn = CACurrentMediaTime()

        center.post(name: .inappSessionChecked, object: nil, userInfo: [Constants.Notification.sessionCheckStartedAt: checkStartedBeforeTheReturn])
        #expect(!presence.isPresent)

        center.post(name: .inappSessionChecked, object: nil, userInfo: [Constants.Notification.sessionCheckStartedAt: checkStartedAfterTheReturn])
        #expect(presence.isPresent)
    }

    @Test("A new session that lands in the background hands the page its data once the user is back, not before")
    func newSessionInTheBackgroundIsPushedOnReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.enterBackground()

        bed.announceNewSession()
        #expect(bed.page?.initDataPushes.isEmpty == true)

        bed.returnToApp()
        bed.finishSessionCheck()

        #expect(bed.page?.initDataPushes == [EmbeddedBlockWebContent.stub.params])
    }

    @Test("A data push left unconfirmed when the app went to the background is waited on again on its remainder once the user is back")
    func dataPushWaitIsSuspendedInTheBackground() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()
        bed.clock.advance(2)

        bed.enterBackground()
        bed.ackScheduler.fire()
        #expect(bed.pageFactory.pages.count == 1)

        bed.returnToApp()
        bed.finishSessionCheck()

        #expect(bed.ackScheduler.scheduled.last?.delay == TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds) - 2)
    }

    @Test("An operation that brings a new session hands the page its data, and its show waits for the redraw")
    func operationInANewSessionPushesAndShowsAfterTheRedraw() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.resolver.sessionEpoch += 1
        _ = bed.announceOperation()
        #expect(bed.page?.initDataPushes == [EmbeddedBlockWebContent.stub.params])
        #expect(bed.accounting.sessionEpochs == [first])

        bed.page?.reportRendered(1)

        #expect(bed.accounting.sessionEpochs == [first, first + 1])
    }

    @Test("The new session's timeToDisplay runs from its own selection to the page's redraw")
    func newSessionTimeToDisplayRunsFromItsSelection() throws {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.processingDuration = 2
        bed.provider.start()
        bed.clock.advance(0.75)
        bed.page?.reportRendered(1)

        bed.clock.advance(100)
        bed.resolver.processingDuration = 0.5
        bed.announceNewSession()
        bed.clock.advance(0.25)
        bed.page?.reportRendered(1)

        let shows = bed.accounting.shows.map(\.timeToDisplay)
        #expect(shows == [2.75, 0.75])
    }

    @Test("A page rebuilt after an unconfirmed push is shown in the session it was pushed for")
    func rebuiltPageIsShownInThePushedSession() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()

        bed.ackScheduler.fire()
        bed.page?.reportRendered(1)

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.accounting.sessionEpochs == [first, first + 1])
    }

    @Test("A page rebuilt after an unconfirmed push times its show from the selection of the session it was pushed for; within a session, from the stored selection",
          arguments: [(isNewSession: true, timeToDisplay: 7.75), (isNewSession: false, timeToDisplay: 2.25)])
    func rebuiltPageTimesItsShowFromThePushedSelection(isNewSession: Bool, timeToDisplay: TimeInterval) {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.processingDuration = 2
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.clock.advance(100)

        if isNewSession {
            bed.resolver.processingDuration = 0.5
            bed.announceNewSession()
        } else {
            bed.deliverSamePageWithNewData()
        }
        bed.clock.advance(7)
        bed.ackScheduler.fire()
        bed.clock.advance(0.25)
        bed.page?.reportRendered(1)

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.accounting.shows.map(\.timeToDisplay) == [2, timeToDisplay])
    }

    @Test("A session that lands while the page has not redrawn the previous one's push takes over: one more push, and one show, for the newest session")
    func newerSessionBeforeTheRedrawTakesOver() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()
        bed.page?.confirmInitData()

        bed.announceNewSession()
        bed.page?.reportRendered(1)

        #expect(bed.page?.initDataPushes.count == 2)
        #expect(bed.accounting.sessionEpochs == [first, first + 2])
    }

    @Test("A page built in place of one that was owed the new session's data is not owed it: it is shown on its own first draw")
    func pageReplacingAnOwedOneIsShownOnItsOwnDraw() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.enterBackground()
        bed.announceNewSession()

        bed.resolver.resolution = .content(.other)
        bed.announceNewConfig()
        bed.returnToApp()
        bed.finishSessionCheck()
        bed.page?.reportRendered(1)

        #expect(bed.page?.initDataPushes.isEmpty == true)
        #expect(bed.accounting.shownIds == [EmbeddedBlockWebContent.stub.inAppId, EmbeddedBlockWebContent.other.inAppId])
        #expect(bed.accounting.sessionEpochs == [first, first + 1])
    }

    // MARK: - A collapse while the user looks

    enum NothingToShow: CaseIterable {
        case empty
        case brokenWinner
        case configUnavailable
        case targetingUnavailable

        var resolution: EmbeddedBlockResolution {
            switch self {
            case .empty: return .empty
            case .brokenWinner: return .failure(.broken)
            case .configUnavailable: return .configUnavailable
            case .targetingUnavailable: return .targetingUnavailable
            }
        }

        var reportedFailures: [InAppShowFailureReason] { self == .brokenWinner ? [.unknownError] : [] }

        var unansweredWaitReports: Int { self == .configUnavailable ? 1 : 0 }
    }

    @Test("A shown block keeps its content while the user looks, whatever its place answers instead, and reports a failure at once",
          arguments: NothingToShow.allCases)
    func shownBlockHoldsTheCollapse(_ answer: NothingToShow) {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = answer.resolution
        bed.announceNewConfig()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView === bed.page?.view)
        #expect(bed.page?.isClosed == false)
        #expect(bed.failureReporter.reasons == answer.reportedFailures)
        #expect(bed.failureReporter.unansweredWaits.count == answer.unansweredWaitReports)
    }

    @Test("A held collapse survives a trip to the background: going to the background is not leaving the screen")
    func heldCollapseSurvivesTheBackground() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.enterBackground()
        bed.returnToApp()
        bed.finishSessionCheck()

        #expect(states.isEmpty)
        #expect(bed.page?.isClosed == false)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    @Test("A held failure reported when it arrived is not reported again when the collapse lands")
    func heldFailureIsReportedOnce() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .failure(.broken)
        bed.announceNewConfig()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.stop()
        bed.provider.start()

        #expect(states.first == .failed(MindboxEmbeddedBlockFailReason(.unknownError)))
        #expect(bed.failureReporter.reasons == [.unknownError])
    }

    @Test("A held collapse drops the page when the user leaves and is applied first thing on the return")
    func heldCollapseIsAppliedOnReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        let resolvesBefore = bed.resolver.resolveCount

        bed.provider.stop()
        #expect(bed.page?.isClosed == true)

        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        #expect(states == [.empty])
        #expect(bed.provider.contentView == nil)
        #expect(bed.resolver.resolveCount == resolvesBefore + 1)
    }

    @Test("A held collapse whose block a screen covered while the app was away, or right after the return, lands when the user comes back to the block",
          arguments: [true, false])
    func heldCollapseLandsWhenTheUserComesBackFromAnotherScreen(coveredWhileAway: Bool) {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.announceNewConfig()

        bed.enterBackground()
        if coveredWhileAway {
            bed.provider.stop()
        }
        bed.returnToApp()
        bed.finishSessionCheck()
        if !coveredWhileAway {
            bed.provider.stop()
        }
        #expect(bed.page?.isClosed == true)

        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        #expect(states == [.empty])
        #expect(bed.provider.contentView == nil)
    }

    @Test("An answer of nothing that arrived off screen collapses a block that showed content on return, never held")
    func parkedCollapseIsNeverHeld() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        bed.resolver.resolution = .empty
        bed.provider.apply(bed.answer(.empty))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.empty])
        #expect(bed.page?.isClosed == true)
    }

    enum ParkedAnswer: CaseIterable {
        case empty
        case anotherPage

        var resolution: EmbeddedBlockResolution { self == .empty ? .empty : .content(.other) }
    }

    @Test("An answer parked in a session that ended while the user was away is dropped on return: the page stays, and the place's answer decides",
          arguments: ParkedAnswer.allCases)
    func parkedAnswerOfAnEndedSessionIsDropped(_ parked: ParkedAnswer) {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        bed.provider.apply(bed.answer(parked.resolution))
        bed.expireSession()
        let resolvesBefore = bed.resolver.resolveCount
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.isClosed == false)
        #expect(bed.resolver.resolveCount == resolvesBefore + 1)
    }

    @Test("A held collapse of a session that ended while the user was away is dropped on return: the block asks its place afresh instead of collapsing")
    func heldCollapseOfAnEndedSessionIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        bed.provider.stop()
        bed.expireSession()
        let resolvesBefore = bed.resolver.resolveCount
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.loading])
        #expect(bed.resolver.resolveCount == resolvesBefore + 1)
    }

    @Test("A failure that reaches a block off screen is reported at once; only the state waits for the return, and a teardown first loses nothing",
          arguments: [NothingToShow.brokenWinner, .configUnavailable], [true, false])
    func parkedFailureIsReportedOnArrival(_ answer: NothingToShow, isTornDownFirst: Bool) {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()

        bed.provider.apply(bed.answer(answer.resolution))
        #expect(bed.failureReporter.reasons == answer.reportedFailures)
        #expect(bed.failureReporter.unansweredWaits.count == answer.unansweredWaitReports)

        if isTornDownFirst {
            bed.provider.teardown()
        } else {
            bed.provider.start()
        }

        #expect(bed.failureReporter.reasons == answer.reportedFailures)
        #expect(bed.failureReporter.unansweredWaits.count == answer.unansweredWaitReports)
    }

    @Test("An answer parked in the session a check is ending is dropped on return, like one of a session that has ended")
    func parkedAnswerOfAnEndingSessionIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        bed.provider.apply(bed.answer(.empty))
        SessionTemporaryStorage.shared.$ledger.mutate { $0.isSessionEnding = true }
        defer { SessionTemporaryStorage.shared.$ledger.mutate { $0.isSessionEnding = false } }
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.page?.isClosed == false)
    }

    @Test("An unavailable config that reaches a block off screen after its session ended is not reported in the session that follows")
    func parkedUnavailableConfigOfAnEndedSessionIsNotReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()
        let answer = bed.answer(.configUnavailable)
        bed.expireSession()

        bed.provider.apply(answer)

        #expect(bed.failureReporter.unansweredWaits.isEmpty)
        #expect(!SessionTemporaryStorage.shared.ledger.placesReportedUnanswered.contains("block-id"))
    }

    @Test("Content answered while a collapse is held keeps the block as it is through the next return")
    func contentCancelsTheHeldCollapse() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.announceNewConfig()

        bed.resolver.resolution = .content(.stub)
        bed.announceNewConfig()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.stop()
        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.isClosed == false)
    }

    @Test("A page its place no longer shows is not shown in the new session when it draws")
    func heldCollapseKeepsTheShowBack() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()

        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        bed.page?.reportRendered(1)

        #expect(bed.accounting.shows.count == 1)
    }

    @Test("Content that lifts a hold the data push ran out under hands the page its data again")
    func contentAfterAHeldTimeoutPushesAgain() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()
        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        bed.ackScheduler.fire()

        bed.resolver.resolution = .content(.stub)
        bed.announceNewConfig()
        #expect(bed.page?.initDataPushes.count == 2)

        bed.page?.reportRendered(1)

        #expect(bed.accounting.sessionEpochs == [first, first + 1])
    }

    @Test("A page its place no longer shows is not rebuilt for a push it never confirmed")
    func heldCollapseIsNotRebuiltOnAckTimeout() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()
        bed.resolver.resolution = .empty
        bed.announceNewConfig()

        bed.ackScheduler.fire()

        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.isClosed == false)
    }

    @Test("A page its place no longer shows is not handed its data while the collapse is held, even when it redraws late; content that lifts the hold hands it once")
    func heldPageIsNotPushedUntilContentLiftsTheHold() {
        let bed = EmbeddedBlockTestBed()
        let first = bed.resolver.sessionEpoch
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.announceNewSession()
        bed.resolver.resolution = .empty
        bed.announceNewConfig()
        bed.ackScheduler.fire()

        bed.page?.reportRendered(1)
        bed.becomeActive()
        #expect(bed.page?.initDataPushes.count == 1)

        bed.resolver.resolution = .content(.stub)
        bed.announceNewConfig()
        #expect(bed.page?.initDataPushes.count == 2)
        #expect(bed.accounting.sessionEpochs == [first])

        bed.page?.reportRendered(1)

        #expect(bed.accounting.sessionEpochs == [first, first + 1])
    }

    @Test("Data a page was owed while the user was away is not handed to it on return while its collapse is held")
    func heldPageIsNotPushedOnReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.enterBackground()
        bed.announceNewSession()
        bed.resolver.resolution = .empty
        bed.announceNewConfig()

        bed.returnToApp()
        bed.finishSessionCheck()

        #expect(bed.page?.initDataPushes.isEmpty == true)
        #expect(bed.page?.isClosed == false)
    }

    // MARK: - Which in-apps the page may draw

    @Test("A loading block answers which in-apps it may draw")
    func loadingBlockAnswersTargeting() {
        let bed = EmbeddedBlockTestBed()
        bed.inappService.allowed = ["story-1"]
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1"), .string("story-2")])])

        #expect(bed.inappService.askedIds == [["story-1", "story-2"]])
        #expect(bed.page?.responses.map(\.payload) == [.object(["inappIds": .array([.string("story-1")])])])
    }

    @Test("The question names the block's own in-app")
    func questionNamesTheBlocksInapp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])

        #expect(bed.inappService.askedBy == [EmbeddedBlockWebContent.stub.inAppId])
    }

    @Test("An answer landing after a stop still reaches the page")
    func answerAfterStopReachesThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.inappService.allowed = ["story-1"]
        bed.inappService.isDeferred = true
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.inappService.flush()

        #expect(bed.page?.responses.map(\.payload) == [.object(["inappIds": .array([.string("story-1")])])])
    }

    @Test("A block off screen answers its page's question")
    func stoppedBlockAnswersTheQuestion() {
        let bed = EmbeddedBlockTestBed()
        bed.inappService.allowed = ["story-1"]
        bed.provider.start()
        bed.provider.stop()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])

        #expect(bed.inappService.askedIds == [["story-1"]])
        #expect(bed.page?.responses.map(\.payload) == [.object(["inappIds": .array([.string("story-1")])])])
    }

    @Test("An answer for a page dropped when the user left a block its place no longer shows is dropped")
    func answerForAPageDroppedOnLeavingIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.inappService.isDeferred = true
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.announceNewConfig()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.inappService.flush()

        #expect(bed.page?.isClosed == true)
        #expect(bed.page?.responses.contains { $0.action == "filterShowableInapps" } == false)
    }

    @Test("An answer for a page the block has since replaced is dropped")
    func answerForAReplacedPageIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.inappService.isDeferred = true
        bed.provider.start()
        let first = bed.page

        first?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])
        bed.provider.reload()
        bed.inappService.flush()

        #expect(first?.responses.isEmpty == true)
    }

    // MARK: - Asking to show an in-app

    @Test("A shown block passes the request on and does not change its own state")
    func shownBlockShowsTheInapp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.map(\.id) == ["story-id"])
        #expect(states.isEmpty)
    }

    @Test("The page hears the show's outcome once it is known, not on handover")
    func pageHearsTheShowOutcome() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.page?.send(.showInApp, ["inappId": .string("story-id")])
        #expect(bed.page?.showInAppResponses.isEmpty == true)
        #expect(bed.page?.showInAppRefusals.isEmpty == true)

        bed.inappService.finishShow(.success(()))

        #expect(bed.page?.showInAppResponses == [.object(["success": .bool(true)])])
    }

    @Test("A show that failed reaches the page as its reason")
    func failedShowReachesThePageAsItsReason() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.page?.send(.showInApp, ["inappId": .string("story-id")])
        bed.inappService.finishShow(.failure(.showFailed))

        #expect(bed.page?.showInAppRefusals == ["show_failed"])
    }

    @Test("The params the page sent are passed on as they are")
    func paramsArePassedOnUntouched() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        let params: [String: JSONValue] = ["formId": .string("160477"),
                                           "lastContentUpdateDateTimeUtc": .string("2026-08-13T09:00:00.000000Z")]
        bed.page?.send(.showInApp, ["inappId": .string("story-id"), "params": .object(params)])

        #expect(bed.inappService.shown.first?.params == params)
    }

    enum BlockExit: CaseIterable {
        case leftTheScreen
        case released
        case reloaded
        case collapsed
        case failed
    }

    @Test("A show the block asked for may start only while that block is still shown", arguments: BlockExit.allCases)
    func showMayStartOnlyWhileTheAskingBlockIsShown(exit: BlockExit) throws {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])
        let requesterIsActive = try #require(bed.inappService.requesterChecks.first)
        #expect(requesterIsActive())

        switch exit {
        case .leftTheScreen:
            bed.provider.stop()
        case .released:
            bed.provider.teardown()
        case .reloaded:
            bed.provider.reload()
        case .collapsed:
            bed.page?.reportRendered(0)
        case .failed:
            bed.page?.failLoad()
        }

        #expect(!requesterIsActive())
    }

    @Test("A show the block asked for does not start once that block is gone")
    func showDoesNotStartOnceTheAskingBlockIsGone() throws {
        var inappService: InappRequestServiceMock?
        weak var released: EmbeddedBlockWebViewProvider?

        autoreleasepool {
            let bed = EmbeddedBlockTestBed()
            bed.provider.start()
            bed.page?.send(.showInApp, ["inappId": .string("story-id")])
            inappService = bed.inappService
            released = bed.provider
        }

        try #require(released == nil)
        let requesterIsActive = try #require(inappService?.requesterChecks.first)
        #expect(!requesterIsActive())
    }

    @Test("A stopped block's request is refused at the presence gate, before the block hears it")
    func stoppedBlockIsRefusedAtThePresenceGate() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        var requestsHeard = 0
        let forward = bed.page?.onShowInAppRequest
        bed.page?.onShowInAppRequest = { inappId, params, completion in
            requestsHeard += 1
            forward?(inappId, params, completion)
        }
        bed.provider.stop()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(requestsHeard == 0)
        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["not_visible"])
    }

    @Test("A block collapsed as empty refuses a show request as not_visible")
    func emptyBlockRefusesShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRendered(0)
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["not_visible"])
    }

    @Test("A failed block refuses a show request as not_visible")
    func failedBlockRefusesShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["not_visible"])
    }

    @Test("A block broken by an unreadable report refuses a show request as not_visible")
    func brokenBlockRefusesShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRenderedWithoutCount()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["not_visible"])
    }

    @Test("A new attempt after a failure acts again")
    func retryAfterFailureActsAgain() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()

        bed.provider.stop()
        bed.provider.start()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.map(\.id) == ["story-id"])
    }

    @Test("A message the block does not own leaves its state alone")
    func foreignMessageLeavesStateAlone() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.page?.send(.click)

        #expect(states.isEmpty)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    // MARK: - Stop and restart

    /// After `stop()` the provider must stay silent — the container relies on this when it
    /// collapses expired content on its own timeout.
    @Test("Stop keeps the page, records what it says and announces nothing")
    func stopPausesThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.stop()
        bed.page?.reportRendered(1)

        #expect(bed.page?.cancelCount == 0)
        #expect(states.isEmpty)

        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    @Test("An abandoned attempt cancels the page and is not resumed")
    func abandonedAttemptCancelsThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.abandonAttempt()

        #expect(bed.page?.cancelCount == 1)
        #expect(bed.provider.contentView == nil)

        bed.provider.start()

        #expect(bed.resolver.resolveCount == 2)
        #expect(states == [.loading])
    }

    @Test("The page is told nobody is looking at it, and told again when the user comes back")
    func stopAndStartTellThePageAboutTheUser() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.provider.stop()
        #expect(bed.page?.isUserPresent == false)

        bed.provider.start()
        #expect(bed.page?.isUserPresent == true)
    }

    @Test("A return resumes a page that never rendered and the same answer changes nothing")
    func returnResumesAPageThatNeverRendered() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.provider.start()
        bed.page?.reportRendered(1)

        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.loadCount == 1)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    @Test("Page rendered before the block left the window is shown again without a reload")
    func renderedPageIsShownAgainWithoutReload() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(states == [.ready])
        #expect(bed.page?.loadCount == 1)
        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    @Test("A page that survived the window round trip can still be told its data changed")
    func returnedPageStillHearsNewData() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        bed.provider.start()

        let sameId = EmbeddedBlockWebContent(inAppId: EmbeddedBlockWebContent.stub.inAppId,
                                             baseUrl: EmbeddedBlockWebContent.stub.baseUrl,
                                             contentUrl: EmbeddedBlockWebContent.stub.contentUrl,
                                             frequency: .unlimited,
                                             tags: EmbeddedBlockWebContent.stub.tags,
                                             params: ["fresh": .bool(true)])
        bed.provider.apply(bed.answer(.content(sameId)))

        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.initDataPushes == [["fresh": .bool(true)]])
    }

    @Test("A return catches up with a config that changed off screen")
    func returnCatchesUpWithAChangedWorld() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()

        bed.resolver.resolution = .content(.other)
        bed.provider.apply(bed.answer(.content(.other)))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        #expect(states == [.loading])
        #expect(bed.accounting.shows.count == 1)
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.contents.last == .other)
    }

    @Test("A return hears about a config that changed while nobody was on the place")
    func returnAsksAgainAfterAnInvalidationItNeverHeard() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()

        bed.resolver.resolution = .content(.other)
        bed.announceNewConfig()
        #expect(bed.pageFactory.pages.count == 1)

        bed.provider.start()

        #expect(bed.pageFactory.contents.last == .other)
        #expect(bed.pageFactory.pages.count == 2)
    }

    @Test("A return with an empty answer in hand still asks the place")
    func returnWithAnEmptyAnswerStillAsks() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()
        bed.provider.stop()
        bed.provider.apply(bed.answer(.empty))

        bed.provider.start()

        #expect(bed.resolver.resolveCount == 2)
    }

    @Test("An empty answer parked for the return collapses the block without accounting the page that drew off screen")
    func parkedEmptyAnswerCollapsesWithoutAShow() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()
        bed.page?.reportRendered(1)
        bed.resolver.resolution = .empty
        bed.provider.apply(bed.answer(.empty))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()

        #expect(bed.accounting.shows.isEmpty)
        #expect(states == [.empty])
        #expect(bed.pageFactory.page?.isClosed == true)
        #expect(bed.resolver.resolveCount == 2)
    }

    @Test("A reload drops the answer parked for the attempt it replaces")
    func reloadDropsTheParkedAnswer() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.abandonAttempt()
        bed.provider.apply(bed.answer(.content(.other)))

        bed.provider.reload()
        #expect(bed.pageFactory.contents.last == .stub)

        bed.provider.stop()
        bed.provider.start()

        #expect(bed.pageFactory.contents.last == .stub)
        #expect(bed.pageFactory.pages.count == 2)
    }

    @Test("A resolution arriving after abandonAttempt is discarded, not parked")
    func resolutionAfterAbandonAttemptIsDiscarded() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.abandonAttempt()

        bed.provider.apply(bed.answer(.content(.other)))
        bed.provider.start()

        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.contents == [.stub, .stub])
    }

    @Test("A failure off screen is reported when the block comes back")
    func failureOffScreenIsHeldUntilTheReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()

        bed.page?.failLoad()

        #expect(bed.failureReporter.reported.isEmpty)

        bed.provider.start()

        #expect(bed.failureReporter.reasons == [.webviewLoadFailed])
    }

    @Test("A data push left unconfirmed off screen is waited on again after the return")
    func dataPushAckIsRearmedAfterAReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()
        #expect(bed.ackScheduler.scheduled.count == 1)

        bed.provider.stop()
        #expect(bed.ackScheduler.scheduled.last?.work.isCancelled == true)

        bed.provider.start()
        #expect(bed.ackScheduler.scheduled.count == 2)

        bed.ackScheduler.fire()

        #expect(bed.pageFactory.pages.count == 2)
    }

    @Test("A data push parked for the return is waited on once")
    func parkedDataPushIsWaitedOnOnce() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()
        let fresh = EmbeddedBlockWebContent(inAppId: EmbeddedBlockWebContent.stub.inAppId,
                                            baseUrl: EmbeddedBlockWebContent.stub.baseUrl,
                                            contentUrl: EmbeddedBlockWebContent.stub.contentUrl,
                                            frequency: EmbeddedBlockWebContent.stub.frequency,
                                            tags: EmbeddedBlockWebContent.stub.tags,
                                            params: ["stories": .array([.string("one")])])
        bed.resolver.resolution = .content(fresh)
        bed.provider.apply(bed.answer(.content(fresh)))

        bed.provider.start()

        #expect(bed.page?.initDataPushes == [fresh.params])
        #expect(bed.ackScheduler.scheduled.count == 1)
        #expect(bed.accounting.shows.count == 1)
    }

    @Test("The confirmation wait resumes on its remainder, not on a full interval")
    func dataPushAckResumesOnTheRemainder() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        let whole = TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
        #expect(bed.ackScheduler.scheduled.map(\.delay) == [whole])

        bed.clock.advance(1)
        bed.provider.stop()
        bed.clock.advance(100)
        bed.provider.start()

        #expect(bed.ackScheduler.scheduled.map(\.delay) == [whole, whole - 1])
    }

    @Test("A confirmation wait spent in full fires the moment the block comes back")
    func dataPushAckSpentInFullFiresOnTheReturn() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        bed.clock.advance(TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds) + 1)
        bed.provider.stop()
        bed.provider.start()

        #expect(bed.ackScheduler.scheduled.last?.delay == 0)

        bed.ackScheduler.fire()

        #expect(bed.pageFactory.pages.count == 2)
    }

    @Test("A fresh data push waits out the whole interval again")
    func freshDataPushGetsTheWholeIntervalBack() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData("first")

        bed.clock.advance(2)
        bed.page?.confirmInitData()
        bed.deliverSamePageWithNewData("second")

        let whole = TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)
        #expect(bed.ackScheduler.scheduled.map(\.delay) == [whole, whole])
    }

    @Test("The show reports the time the render took, not the time spent off screen")
    func showReportsTheRenderTimeNotTheAbsence() throws {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.processingDuration = 2

        bed.provider.start()
        bed.clock.advance(0.75)
        bed.provider.stop()
        bed.page?.reportRendered(1)

        bed.clock.advance(8)
        bed.provider.start()

        let show = try #require(bed.accounting.shows.first)
        #expect(show.timeToDisplay == 2.75)
    }

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
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.page?.loadCount == 1)
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

    @Test("Reload asks for the content again and builds a new page")
    func reloadRefetchesTheContent() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        let firstPage = bed.page
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .content(.other)
        bed.provider.reload()

        #expect(bed.resolver.resolveCount == 2)
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
        bed.page?.reportRendered(1)
        let firstPage = bed.page
        bed.provider.reload()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        firstPage?.reportRendered(1)
        firstPage?.failLoad()

        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    @Test("Reload during an in-flight resolve is covered by its answer")
    func reloadDuringResolveIsCoveredByItsAnswer() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.reload()
        bed.resolver.flush()

        #expect(bed.resolver.resolveCount == 1)
        #expect(bed.pageFactory.pages.count == 1)
    }

    @Test("Reloaded block becomes ready through the same path")
    func reloadedBlockBecomesReady() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.provider.reload()
        bed.page?.reportRendered(1)

        #expect(bed.provider.contentView === bed.page?.view)
    }
}
