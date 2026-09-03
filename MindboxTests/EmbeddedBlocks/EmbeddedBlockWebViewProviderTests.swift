//
//  EmbeddedBlockWebViewProviderTests.swift
//  MindboxTests
//
//  Created by vailence on 03.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
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

        #expect(states.last == .failed)
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

        #expect(states.last == .failed)
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

        bed.provider.reportPageTimedOut()

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

        bed.provider.apply(.content(.stub), processingDuration: 0)

        #expect(!bed.provider.isAwaitingDelayedContent)
    }

    @Test("A block the SDK never answered reports one failure without an in-app")
    func unansweredBlockReportsOneUnattributedFailure() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.reportAnswerTimedOut(waited: 30)

        #expect(bed.failureReporter.unansweredWaits == [30])
        #expect(bed.failureReporter.reported.isEmpty)
    }

    @Test("A second unanswered wait at the same place in one session reports nothing")
    func secondUnansweredWaitIsSilent() {
        let bed = EmbeddedBlockTestBed()
        bed.resolver.isDeferred = true
        bed.provider.start()

        bed.provider.reportAnswerTimedOut(waited: 30)
        bed.provider.reportAnswerTimedOut(waited: 30)

        #expect(bed.failureReporter.unansweredWaits.count == 1)
    }

    @Test("Another place's unanswered wait is reported on its own")
    func anotherPlacesUnansweredWaitIsReported() {
        let first = EmbeddedBlockTestBed(placeSystemName: "first-place")
        let second = EmbeddedBlockTestBed(placeSystemName: "second-place")

        first.provider.reportAnswerTimedOut(waited: 30)
        second.provider.reportAnswerTimedOut(waited: 30)

        #expect(first.failureReporter.unansweredWaits.count == 1)
        #expect(second.failureReporter.unansweredWaits.count == 1)
    }

    @Test("An empty place reports nothing")
    func emptyPlaceReportsNothing() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()

        bed.provider.reportPageTimedOut()

        #expect(bed.failureReporter.reported.isEmpty)
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

    @Test("A place the new config dropped collapses the block")
    func droppedPlaceCollapsesTheBlock() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.resolver.resolution = .empty
        bed.announceNewConfig()

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
        bed.announceNewConfig()

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

    @Test("An answer landing after a stop is dropped")
    func answerAfterStopIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.inappService.isDeferred = true
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.inappService.flush()

        #expect(bed.page?.responses.isEmpty == true)
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

    @Test("A stopped block's request is refused at the presence gate, before the block hears it")
    func stoppedBlockIsRefusedAtThePresenceGate() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["Nobody is looking at this page"])
    }

    @Test("A block collapsed as empty refuses a show request as source_dismissed")
    func emptyBlockRefusesShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRendered(0)
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["source_dismissed"])
    }

    @Test("A failed block refuses a show request as source_dismissed")
    func failedBlockRefusesShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["source_dismissed"])
    }

    @Test("A block broken by an unreadable report refuses a show request as source_dismissed")
    func brokenBlockRefusesShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRenderedWithoutCount()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.inappService.shown.isEmpty)
        #expect(bed.page?.showInAppRefusals == ["source_dismissed"])
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
        bed.provider.apply(.content(sameId), processingDuration: 0)

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
        bed.provider.apply(.content(.other), processingDuration: 0)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        #expect(states.first == .ready)
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
        bed.provider.apply(.empty, processingDuration: 0)

        bed.provider.start()

        #expect(bed.resolver.resolveCount == 2)
    }

    @Test("A reload drops the answer parked for the attempt it replaces")
    func reloadDropsTheParkedAnswer() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.abandonAttempt()
        bed.provider.apply(.content(.other), processingDuration: 0)

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

        bed.provider.apply(.content(.other), processingDuration: 0)
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
