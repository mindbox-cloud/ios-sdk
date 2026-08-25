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

        bed.page?.reportRendered(1)
        bed.page?.reportRendered(0)

        #expect(states == [.ready, .empty])
        #expect(bed.provider.contentView == nil)
    }

    // MARK: - Counting the show

    /// Counted by the frequency's rule — same as the overlay path and Android; nothing else on the place path writes this history.
    @Test("A block that drew its page counts the show")
    func renderedBlockCountsTheShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showRecorder.recorded == [EmbeddedBlockWebContent.stub.inAppId])
    }

    @Test("An unlimited block counts nothing")
    func unlimitedBlockCountsNothing() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showRecorder.recorded.isEmpty)
    }

    // MARK: - Reporting the show

    @Test("A block that drew its page reports the show")
    func renderedBlockReportsTheShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showReporter.inAppIds == [EmbeddedBlockWebContent.stub.inAppId])
        #expect(bed.showReporter.reported.first?.tags == EmbeddedBlockWebContent.stub.tags)
    }

    @Test("Nothing drawn, nothing reported")
    func pageWithoutContentReportsNoShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(0)

        #expect(bed.showReporter.reported.isEmpty)
    }

    @Test("A negative count is a failure, not an empty block")
    func negativeCountIsFailure() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.reportRendered(-1)

        #expect(states.last == .failed)
        #expect(bed.showReporter.reported.isEmpty)
        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    @Test("A page that failed to load reports no show")
    func failedPageReportsNoShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.failLoad()

        #expect(bed.showReporter.reported.isEmpty)
    }

    @Test("An unreadable report is a failure, not a show")
    func unreadableReportIsNoShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRenderedWithoutCount()

        #expect(bed.showReporter.reported.isEmpty)
        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    @Test("A page reporting itself again reports one show")
    func repeatedReportSendsOneEvent() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.page?.reportRendered(4)

        #expect(bed.showReporter.reported.count == 1)
    }

    /// In sync with Android: one show per in-app per session, while the local history stays per rendered page.
    @Test("A page rebuilt in the same session reports no second show")
    func rebuiltPageInSessionReportsNoSecondShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))
        bed.provider.start()
        bed.page?.reportRendered(3)

        bed.provider.reload()
        bed.page?.reportRendered(3)

        #expect(bed.showReporter.reported.count == 1)
        #expect(bed.showRecorder.recorded.count == 2)
    }

    @Test("Another in-app at the place reports its own show")
    func anotherInappAtThePlaceReportsItsOwnShow() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        bed.resolver.resolution = .content(.other)
        bed.announceNewConfig()
        bed.page?.reportRendered(1)

        #expect(bed.showReporter.inAppIds == [EmbeddedBlockWebContent.stub.inAppId,
                                              EmbeddedBlockWebContent.other.inAppId])
    }

    @Test("A new session reports the show again")
    func newSessionReportsTheShowAgain() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)

        SessionTemporaryStorage.shared.blockShowsReportedInSession = []
        bed.provider.reload()
        bed.page?.reportRendered(1)

        #expect(bed.showReporter.reported.count == 2)
    }

    /// The backend parses one format for overlay and block alike — the value is a real measurement, so only its shape is pinned.
    @Test("The reported show carries a timeToDisplay in the overlay's format")
    func reportedShowCarriesTimeToDisplay() throws {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        let timeToDisplay = try #require(bed.showReporter.reported.first?.timeToDisplay)
        #expect(timeToDisplay.range(of: #"^\d+:\d{2}:\d{2}\.\d{7}$"#, options: .regularExpression) != nil,
                "timeToDisplay '\(timeToDisplay)' is not the format toTimeSpan() produces")
    }

    @Test("A page that drew nothing counts no show")
    func emptyPageCountsNoShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(0)

        #expect(bed.showRecorder.recorded.isEmpty)
    }

    @Test("A page that failed to load counts no show")
    func failedPageCountsNoShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.failLoad()

        #expect(bed.showRecorder.recorded.isEmpty)
    }

    @Test("A page reporting itself again counts one show")
    func repeatedReportCountsOneShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.page?.reportRendered(4)

        #expect(bed.showRecorder.recorded.count == 1)
    }

    @Test("A page shown again on return counts no second show")
    func returningBlockCountsNoSecondShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.provider.stop()
        bed.provider.start()

        #expect(bed.showRecorder.recorded.count == 1)
    }

    @Test("A page built again counts its own show")
    func rebuiltPageCountsItsOwnShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.provider.reload()
        bed.page?.reportRendered(3)

        #expect(bed.showRecorder.recorded.count == 2)
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

    // MARK: - The data push's confirmation

    /// A feed silently showing yesterday's stories is the failure nobody files a report about — same remedy as Android's.
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

    /// A data push confirmation arriving while paused (provider stopped) clears the standing wait.
    /// When the provider resumes, no new timeout is scheduled and the page is not rebuilt.
    @Test("A data push confirmation arriving while paused clears the wait and prevents rebuild on return")
    func dataPushConfirmationWhilePausedClearsTheWait() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()
        #expect(bed.ackScheduler.scheduled.count == 1)

        bed.provider.stop()
        // Confirmation arrives while paused
        bed.page?.confirmInitData()

        // The wait is now cleared
        bed.provider.start()

        // No new timeout was scheduled after start
        #expect(bed.ackScheduler.scheduled.count == 1)
        // Page was not rebuilt
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

    @Test("The same answer revives a page that was collapsed by a dropped place")
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

        #expect(bed.page?.initDataPushes.count == 1)
        #expect(bed.pageFactory.pages.count == 1)
        #expect(states.isEmpty)
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

    // MARK: - Which in-apps the feed may draw

    @Test("A loading block answers which in-apps it may draw")
    func loadingBlockAnswersTargeting() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.allowed = ["story-1"]
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1"), .string("story-2")])])

        #expect(bed.feed.askedIds == [["story-1", "story-2"]])
        #expect(bed.page?.responses.map(\.payload) == [.object(["inappIds": .array([.string("story-1")])])])
    }

    @Test("A delivered answer is vouched for once")
    func deliveredAnswerIsVouchedFor() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.allowed = ["story-1", "story-2"]
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1"), .string("story-2")])])

        #expect(bed.feed.vouchCount == 1)
    }

    @Test("An answer landing after a stop is not vouched for")
    func droppedAnswerIsNotVouchedFor() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.allowed = ["story-1"]
        bed.feed.isDeferred = true
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.feed.flush()

        #expect(bed.feed.vouchCount == 0)
    }

    @Test("An answer landing after a stop is dropped")
    func answerAfterStopIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.isDeferred = true
        bed.provider.start()

        bed.page?.send(.filterShowableInapps, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.feed.flush()

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

        #expect(bed.feed.shown.map(\.id) == ["story-id"])
        #expect(states.isEmpty)
    }

    @Test("The params the page sent are passed on as they are")
    func paramsArePassedOnUntouched() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        let params: [String: JSONValue] = ["formId": .string("160477"),
                                           "lastContentUpdateDateTimeUtc": .string("2026-08-13T09:00:00.000000Z")]
        bed.page?.send(.showInApp, ["inappId": .string("story-id"), "params": .object(params)])

        #expect(bed.feed.shown.first?.params == params)
    }

    @Test("A stopped block does not answer at all")
    func stoppedBlockDoesNotAnswer() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.isEmpty)
    }

    @Test("A block collapsed as empty does not act on a show request")
    func emptyBlockDoesNotActOnShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRendered(0)
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.isEmpty)
    }

    @Test("A failed block does not act on a show request")
    func failedBlockDoesNotActOnShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.isEmpty)
    }

    @Test("A block broken by an unreadable report does not act on a show request")
    func brokenBlockDoesNotActOnShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRenderedWithoutCount()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.isEmpty)
    }

    @Test("A new attempt after a failure acts again")
    func retryAfterFailureActsAgain() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.failLoad()

        bed.provider.stop()
        bed.provider.start()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.map(\.id) == ["story-id"])
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
    /// collapses expired content on its own timeout. Silent, but not deaf: the page lives on and
    /// what it says is kept for the return.
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

        // The page finished behind another screen, and the return is where that is heard.
        #expect(states == [.ready])
        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// An attempt the container gave up on is a different matter: it is closed, and the page cannot
    /// report its way back into a block that has already collapsed.
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

        // Nothing to resume, so the block starts a cycle anew.
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

    /// A return is a resume, not a retry: a page that is still loading is the same page. The place
    /// is asked again all the same — an invalidation that landed off screen was dropped where it
    /// happened — and an unchanged answer is deduplicated against the page that already stands, so
    /// the block that never stopped trying is not made to start over.
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

    /// An empty place is an answer, not a breakage: the page that gave it stands, and it is the one
    /// that revives the block when it has something to draw after all.
    @Test("A return resumes the page of a block that had collapsed as empty")
    func returnResumesACollapsedPage() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(0)
        bed.provider.stop()
        bed.provider.start()
        bed.page?.reportRendered(2)

        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.pages.count == 1)
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
        // The place is asked again on the way back, and the answer it gives is the page that stands.
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
        bed.provider.apply(.content(sameId))

        #expect(bed.pageFactory.pages.count == 1)
        #expect(bed.page?.initDataPushes == [["fresh": .bool(true)]])
    }

    @Test("A return catches up with a config that changed off screen")
    func returnCatchesUpWithAChangedWorld() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()

        // The place moved on while the block was off screen: the answer that landed then is kept
        // rather than dropped, and the registry now answers the same way — the ask the return makes
        // finds the world the block has just been told about.
        bed.resolver.resolution = .content(.other)
        bed.provider.apply(.content(.other))
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        // Where the block was left, and only then what it has become.
        #expect(states.first == .ready)
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.contents.last == .other)
    }

    /// The registry drops an invalidation that lands on a place with no block on screen — it has
    /// nowhere to draw it, and nobody re-sends it. So the return asks for itself.
    @Test("A return hears about a config that changed while nobody was on the place")
    func returnAsksAgainAfterAnInvalidationItNeverHeard() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()

        // The config arrives while the block is away, so there is nowhere to deliver it.
        bed.resolver.resolution = .content(.other)
        bed.announceNewConfig()
        #expect(bed.pageFactory.pages.count == 1)

        bed.provider.start()

        #expect(bed.pageFactory.contents.last == .other)
        #expect(bed.pageFactory.pages.count == 2)
    }

    /// An empty place is an answer, not a substitute for asking: a block that comes back with one in
    /// hand and nothing to build still has to find out whether the place has filled up since.
    @Test("A return with an empty answer in hand still asks the place")
    func returnWithAnEmptyAnswerStillAsks() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()
        bed.provider.stop()
        bed.provider.apply(.empty)

        bed.provider.start()

        #expect(bed.resolver.resolveCount == 2)
    }

    /// A reload replaces the attempt an answer belonged to: parked for a screen that is gone, it must
    /// not resurface over the page the reload builds.
    @Test("A reload drops the answer parked for the attempt it replaces")
    func reloadDropsTheParkedAnswer() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.abandonAttempt()
        bed.provider.apply(.content(.other))

        bed.provider.reload()
        #expect(bed.pageFactory.contents.last == .stub)

        bed.provider.stop()
        bed.provider.start()

        #expect(bed.pageFactory.contents.last == .stub)
        #expect(bed.pageFactory.pages.count == 2)
    }

    /// Only a pause keeps an answer for the return — an abandoned attempt is not coming back, so a
    /// late answer to it is discarded rather than parked: kept, it would have the next `start()`
    /// build the stale page before the fresh answer arrived.
    @Test("A resolution arriving after abandonAttempt is discarded, not parked")
    func resolutionAfterAbandonAttemptIsDiscarded() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.abandonAttempt()

        bed.provider.apply(.content(.other))
        bed.provider.start()

        // The next start began a cycle anew: the place was asked again and its own answer was
        // built — the answer left over from the abandoned attempt never was.
        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.contents == [.stub, .stub])
    }

    /// The backend hears about blocks the user was shown: a page that failed behind another screen is
    /// reported when somebody looks at the block, not while nobody does.
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

    /// The page's wait for a confirmation pauses with the block: data nobody answered for is still
    /// unanswered on the way back, and a page that never confirms is rebuilt — as it is on Android.
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

    /// `timeToDisplay` measures the wait for the page, not the user's absence from the screen: the
    /// show is counted by the return, with the time the render itself took.
    @Test("The show reports the time the render took, not the time spent off screen")
    func showReportsTheRenderTimeNotTheAbsence() async throws {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.provider.stop()
        bed.page?.reportRendered(1)

        try await Task.sleep(nanoseconds: 1_200_000_000)
        bed.provider.start()

        // A whole second would be the one the block spent behind another screen.
        #expect(bed.showReporter.reported.count == 1)
        #expect(bed.showReporter.reported.first?.timeToDisplay.hasPrefix("0:00:00.") == true)
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
