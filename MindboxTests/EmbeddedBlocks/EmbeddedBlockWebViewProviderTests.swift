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

    /// Only the page itself reports what it drew — it is the single source of truth.
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

    /// Zero items is a valid outcome and says so explicitly, so a report nobody can read is a broken
    /// protocol: an empty strip inside someone's list is worse than a collapsed one.
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

    /// The count comes from the page, so it can be any number JSON allows. One outside `Int` is a count
    /// nobody can read — the same outcome as a report without one, and emphatically not a crash in the
    /// host app.
    @Test("A count too large for an integer is a failure, not a crash")
    func hugeCountIsFailure() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.contentRendered, ["count": .double(1e30)])

        #expect(states.last == .failed)
        #expect(bed.provider.contentView == nil)
    }

    /// A fractional count is a page bug, not a rounding exercise: `0.4` rounded would collapse the
    /// block as empty and `0.6` would show it — the same bug, two opposite fates. Refused instead,
    /// and the refusal is the block's failure (one rule with Android and the overlay's handler).
    @Test("A fractional count is refused as unreadable")
    func fractionalCountIsRefused() {
        let bed = EmbeddedBlockTestBed()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.start()
        bed.page?.send(.contentRendered, ["count": .double(2.5)])

        #expect(states.last == .failed)
        #expect(bed.failureReporter.reasons == [.presentationFailed])
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

    /// A drawn page is a show of the in-app behind it, written down by the frequency's rule — the same
    /// rule the overlay path follows, and the same one Android counts by. This is what makes a `once` or
    /// `periodic` embedded in-app mean anything: nothing else on the place path writes to the history
    /// its frequency is checked against.
    @Test("A block that drew its page counts the show")
    func renderedBlockCountsTheShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showRecorder.recorded == [EmbeddedBlockWebContent.stub.inAppId])
    }

    /// The frequency blocks arrive with by contract, so in the field nothing is ever written.
    @Test("An unlimited block counts nothing")
    func unlimitedBlockCountsNothing() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showRecorder.recorded.isEmpty)
    }

    // MARK: - Reporting the show

    /// The show event is the block's only "it worked" signal: without it a feed has a targeting and,
    /// when things go wrong, a failure — and nothing in between. The tags travel with it, which is what
    /// lets metrics tell a block's show apart from an overlay's.
    @Test("A block that drew its page reports the show")
    func renderedBlockReportsTheShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showReporter.inAppIds == [EmbeddedBlockWebContent.stub.inAppId])
        #expect(bed.showReporter.reported.first?.tags == EmbeddedBlockWebContent.stub.tags)
    }

    /// The half that must not follow the frequency. Blocks arrive `unlimited`, so a show event tied to
    /// the frequency would never be sent at all in the field — the funnel would show every feed as
    /// offered and never displayed.
    @Test("An unlimited block reports the show it does not count")
    func unlimitedBlockStillReportsTheShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        #expect(bed.showRecorder.recorded.isEmpty)
        #expect(bed.showReporter.inAppIds == [EmbeddedBlockWebContent.stub.inAppId])
    }

    /// The cases that write no history send no event either: what is reported is a show, and
    /// none of these put anything in front of the user.
    @Test("Nothing drawn, nothing reported")
    func pageWithoutContentReportsNoShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(0)

        #expect(bed.showReporter.reported.isEmpty)
    }

    /// A page cannot draw minus one story: the number is a page bug, and it must land in the
    /// metrics rather than pass for an empty feed.
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

    /// A report nobody can read says nothing about what is on screen, so it is a failure and not a
    /// show — both events must not go out for the same page.
    @Test("An unreadable report is a failure, not a show")
    func unreadableReportIsNoShow() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRenderedWithoutCount()

        #expect(bed.showReporter.reported.isEmpty)
        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    /// One page is one show on this side too, or a page that re-reports itself after `initDataUpdated`
    /// would inflate the numerator of every feed's funnel.
    @Test("A page reporting itself again reports one show")
    func repeatedReportSendsOneEvent() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.page?.reportRendered(4)

        #expect(bed.showReporter.reported.count == 1)
    }

    /// In sync with Android: within a session the same in-app reports one show, however many pages it
    /// took to draw it — a rebuilt page re-draws what the user already saw. The local history is the
    /// other half of the split and stays per rendered page, on both platforms.
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

    /// The dedup is keyed by the in-app, not by the place: a different in-app winning the place is a
    /// new show the funnel must see.
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

    /// The dedup lives and dies with the session — a new one starts the funnel over.
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

    /// `timeToDisplay` has to be the same shape the overlay sends, because the backend parses one
    /// format for both. The value is a real measurement, so only its shape is pinned here.
    @Test("The reported show carries a timeToDisplay in the overlay's format")
    func reportedShowCarriesTimeToDisplay() throws {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(3)

        let timeToDisplay = try #require(bed.showReporter.reported.first?.timeToDisplay)
        #expect(timeToDisplay.range(of: #"^\d+:\d{2}:\d{2}\.\d{7}$"#, options: .regularExpression) != nil,
                "timeToDisplay '\(timeToDisplay)' is not the format toTimeSpan() produces")
    }

    /// Nothing on screen is not a show. A block whose page drew an empty feed has not spent its only
    /// `once` — otherwise a page that had nothing to draw for a moment would take the in-app away for good.
    @Test("A page that drew nothing counts no show")
    func emptyPageCountsNoShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(0)

        #expect(bed.showRecorder.recorded.isEmpty)
    }

    /// A page that never loaded showed nothing, so there is nothing to count — the report is what
    /// decides, not the resolve.
    @Test("A page that failed to load counts no show")
    func failedPageCountsNoShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.failLoad()

        #expect(bed.showRecorder.recorded.isEmpty)
    }

    /// One page is one show. A page reports itself again after being told its data changed, and that is
    /// the same strip in front of the same user.
    @Test("A page reporting itself again counts one show")
    func repeatedReportCountsOneShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.page?.reportRendered(4)

        #expect(bed.showRecorder.recorded.count == 1)
    }

    /// The page rendered earlier is shown as it was, without a reload — and it was counted when it was
    /// drawn. Counting every return would turn one show into as many as the user scrolls.
    @Test("A page shown again on return counts no second show")
    func returningBlockCountsNoSecondShow() {
        let bed = EmbeddedBlockTestBed(resolution: .content(.counted()))

        bed.provider.start()
        bed.page?.reportRendered(3)
        bed.provider.stop()
        bed.provider.start()

        #expect(bed.showRecorder.recorded.count == 1)
    }

    /// A page built anew is a new show: the previous one is gone from the screen, and what the user sees
    /// now was drawn for them again.
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

    /// A block that could not load its page is a failed show, and the backend hears about it — with the
    /// in-app's tags, which is what tells a block's failure apart from an overlay's.
    @Test("A page that failed to load is reported")
    func loadFailureIsReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.failLoad()

        #expect(bed.failureReporter.reasons == [.webviewLoadFailed])
        #expect(bed.failureReporter.reported.first?.inAppId == EmbeddedBlockWebContent.stub.inAppId)
        #expect(bed.failureReporter.reported.first?.tags == EmbeddedBlockWebContent.stub.tags)
    }

    /// A report nobody can read is the other kind of breakage: the page is there, but what it says about
    /// itself is unusable.
    @Test("An unreadable report is reported as a presentation failure")
    func unreadableReportIsReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRenderedWithoutCount()

        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    /// And the container's patience running out on a built page is reported through the same channel.
    @Test("A page that ran out of patience is reported")
    func timedOutPageIsReported() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.provider.reportPageTimedOut()

        #expect(bed.failureReporter.reasons == [.presentationFailed])
    }

    /// Nothing to blame before the place answers: an empty place is an outcome, not a failure.
    @Test("An empty place reports nothing")
    func emptyPlaceReportsNothing() {
        let bed = EmbeddedBlockTestBed(resolution: .empty)
        bed.provider.start()

        bed.provider.reportPageTimedOut()

        #expect(bed.failureReporter.reported.isEmpty)
    }

    /// A page that drew nothing is not a failure either — the admin panel simply has nothing right now.
    @Test("A page that drew nothing reports nothing")
    func emptyPageReportsNothing() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRendered(0)

        #expect(bed.failureReporter.reported.isEmpty)
    }

    // MARK: - A new config

    /// The same page with new data is told, not replaced: reloading would throw away a rendered feed to
    /// show the very same page again.
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

    /// A pushed `initDataUpdated` is a promise: the page answers it and re-reports. A page that
    /// answers nothing within the budget is rebuilt — a feed silently showing yesterday's stories is
    /// the failure nobody files a report about. Same remedy as Android's.
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

    /// A stopped provider stays silent — the wait dies with the attempt, and the next start() pulls
    /// the place from scratch anyway.
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

    /// The wait rides the page budget, not its own number: what the page owes after a push is the
    /// same thing it owes after a load — a report about itself.
    @Test("The confirmation wait uses the page budget")
    func ackWaitUsesThePageBudget() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.deliverSamePageWithNewData()

        #expect(bed.ackScheduler.scheduled.map(\.delay) == [TimeInterval(Constants.EmbeddedBlock.readyTimeoutSeconds)])
    }

    /// Another in-app at the same place means another page: its start payload would be built around the
    /// wrong in-app id, so telling the live page would describe something it is not.
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

    /// A block outside the window re-resolves from scratch when it comes back, so pushing into it would
    /// be answering a question nobody asked.
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

    /// An invalidation landing mid-resolve is queued, not run alongside and not dropped: the pass in
    /// flight may be reading the config the invalidation is about, so one more pass follows it.
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

    /// The window the self-driving blocks used to lose: an operation firing while the first resolve
    /// is still waiting — on a cold start that is the whole config wait. The queued pass carries the
    /// operation, so its targeting context survives to the pass that can actually use it.
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

    /// A started block that settled as empty sits on the screen collapsed. A new config may be exactly
    /// what gives its place content, and waiting for the user to scroll away and back is not an answer.
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

    /// A page that never loaded cannot be told anything — a push would land in a dead document. The
    /// world changed, so the attempt starts over with a new page.
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

    /// The push side. The operation travels into the resolve, so targeting runs in its context and an
    /// operation-targeted in-app can reach the place; the block itself stays a pull machine.
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

    /// The registry answers every pull and every invalidation, so most answers repeat what the block
    /// already shows. The very same answer moves nothing: no push into the page, no state change.
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

    /// A collapsed page is deliberately not deduplicated: for it the same answer is news — the place
    /// is back, and the re-sent data is what makes the page re-report itself and revive.
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

    /// The question is answered for as long as the block is running — including while it is still
    /// loading, which is exactly when a feed asks.
    @Test("A loading block answers which in-apps it may draw")
    func loadingBlockAnswersTargeting() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.allowed = ["story-1"]
        bed.provider.start()

        bed.page?.send(.checkInappsTargeting, ["inappIds": .array([.string("story-1"), .string("story-2")])])

        #expect(bed.feed.askedIds == [["story-1", "story-2"]])
        #expect(bed.page?.responses.map(\.payload) == [.object(["inappIds": .array([.string("story-1")])])])
    }

    /// Answering is the only place a feed's items are filtered, so an unreadable question is refused
    /// rather than answered with an empty list: a refusal the page can retry, an empty answer it would
    /// take for the truth.
    @Test("A question without an id list is refused, not answered empty")
    func questionWithoutIdsIsRefused() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.checkInappsTargeting)

        #expect(bed.feed.askedIds.isEmpty)
        #expect(bed.page?.responses.isEmpty == true)
        #expect(bed.page?.refusals.count == 1)
    }

    @Test("Ids that are not strings are left out of the question")
    func nonStringIdsAreSkipped() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.checkInappsTargeting, ["inappIds": .array([.string("story-1"), .int(7)])])

        #expect(bed.feed.askedIds == [["story-1"]])
    }

    /// Vouching belongs to the delivered answer: what the page was told is what was offered.
    @Test("A delivered answer is vouched for once")
    func deliveredAnswerIsVouchedFor() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.allowed = ["story-1", "story-2"]
        bed.provider.start()

        bed.page?.send(.checkInappsTargeting, ["inappIds": .array([.string("story-1"), .string("story-2")])])

        #expect(bed.feed.vouchCount == 1)
    }

    /// And an answer nobody received is not vouched for: the block stopped while the selection was
    /// running, so the page was never told about those in-apps.
    @Test("An answer landing after a stop is not vouched for")
    func droppedAnswerIsNotVouchedFor() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.allowed = ["story-1"]
        bed.feed.isDeferred = true
        bed.provider.start()

        bed.page?.send(.checkInappsTargeting, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.feed.flush()

        #expect(bed.feed.vouchCount == 0)
    }

    /// The answer may land after the block was stopped or reloaded. Writing it into the page then would
    /// answer a question the current page never asked.
    @Test("An answer landing after a stop is dropped")
    func answerAfterStopIsDropped() {
        let bed = EmbeddedBlockTestBed()
        bed.feed.isDeferred = true
        bed.provider.start()

        bed.page?.send(.checkInappsTargeting, ["inappIds": .array([.string("story-1")])])
        bed.provider.stop()
        bed.feed.flush()

        #expect(bed.page?.responses.isEmpty == true)
    }

    // MARK: - Asking to show an in-app

    /// Showing an in-app is not the block's own state changing: the block stays exactly as it was, with
    /// the story on top of it.
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

    /// The catalog entry the page drew travels into the shown in-app untouched. The block does not read
    /// it — for the block these params are an opaque dictionary.
    @Test("The params the page sent are passed on as they are")
    func paramsArePassedOnUntouched() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        let params: [String: JSONValue] = ["formId": .string("160477"),
                                           "lastChangedDateTimeUtc": .string("2026-08-13T09:00:00.000000Z")]
        bed.page?.send(.showInApp, ["inappId": .string("story-id"), "params": .object(params)])

        #expect(bed.feed.shown.first?.params == params)
    }

    @Test("A request without an id is refused and shows nothing")
    func showWithoutIdIsRefused() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.showInApp, ["params": .object(["formId": .string("160477")])])

        #expect(bed.feed.shown.isEmpty)
        #expect(bed.page?.refusals.count == 1)
    }

    @Test("An empty id is refused too")
    func showWithEmptyIdIsRefused() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.send(.showInApp, ["inappId": .string("")])

        #expect(bed.feed.shown.isEmpty)
        #expect(bed.page?.refusals.count == 1)
    }

    /// A stopped provider stays silent entirely.
    @Test("A stopped block does not answer at all")
    func stoppedBlockDoesNotAnswer() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.isEmpty)
    }

    /// A collapsed block does not kill the page — it stays alive and may still deliver what it
    /// scheduled. But no user touch stands behind an invisible block, and an in-app would appear
    /// over the app out of nowhere.
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

    /// A report nobody can read is the same as a block not shown: it does not act either.
    @Test("A block broken by an unreadable report does not act on a show request")
    func brokenBlockDoesNotActOnShowInApp() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()

        bed.page?.reportRenderedWithoutCount()
        bed.page?.send(.showInApp, ["inappId": .string("story-id")])

        #expect(bed.feed.shown.isEmpty)
    }

    /// The ban rests on the attempt's outcome, not on the page: a new attempt is live again.
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

    /// An overlay's window lifecycle has no meaning for a block, and a message it does not own must
    /// not move its state.
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
    @Test("Stop cancels the page and ignores what it says afterwards")
    func stopCancelsThePage() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }

        bed.provider.stop()
        bed.page?.reportRendered(1)

        #expect(bed.page?.cancelCount == 1)
        #expect(states.isEmpty)
        #expect(bed.provider.contentView == nil)
    }

    /// The container calls `start()` every time it returns to the window, and every return pulls the
    /// place again — the world may have changed off screen. A page that never rendered does not survive
    /// that round trip: stopping it closed its web layer for good, so the return builds a new page and
    /// the block gets to render after all. Reusing the old one would leave the block loading forever.
    @Test("A return builds a new page when the previous one never rendered")
    func returnRebuildsAPageThatNeverRendered() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.provider.stop()
        bed.provider.start()
        bed.page?.reportRendered(1)

        #expect(bed.resolver.resolveCount == 2)
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.page?.loadCount == 1)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// The same trap on the other outcome: a page that reported "nothing to draw" was stopped just as
    /// dead, so the return rebuilds it instead of asking the collapsed page to load again.
    @Test("A return builds a new page for a block that had collapsed as empty")
    func returnRebuildsACollapsedPage() {
        let bed = EmbeddedBlockTestBed()

        bed.provider.start()
        bed.page?.reportRendered(0)
        bed.provider.stop()
        bed.provider.start()
        bed.page?.reportRendered(2)

        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.provider.contentView === bed.page?.view)
    }

    /// The block left the screen already shown — on return it is shown as is, before the pull's
    /// answer even arrives, and the unchanged answer then moves nothing.
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

    /// A rendered page is the one page a stop must leave alone. Cancelling closes its web layer for
    /// good, and the block goes on showing that page after the return — so a cancelled one could never
    /// be told its data changed, and the block would keep showing content the config has moved past.
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

    /// The divergence the return used to hide: the config changed while the block was off screen.
    /// The instant show still happens — and the pull that follows brings the block up to date.
    @Test("A return catches up with a config that changed off screen")
    func returnCatchesUpWithAChangedWorld() {
        let bed = EmbeddedBlockTestBed()
        bed.provider.start()
        bed.page?.reportRendered(1)
        bed.provider.stop()

        bed.resolver.resolution = .content(.other)
        var states: [EmbeddedBlockState] = []
        bed.provider.onStateChange = { states.append($0) }
        bed.provider.start()

        #expect(states.first == .ready)
        #expect(bed.pageFactory.pages.count == 2)
        #expect(bed.pageFactory.contents.last == .other)
    }

    /// But a block that failed to show gets a new attempt on return — this is the only retry the
    /// block has for now, and the attempt is a fresh page rather than the dead one asked to load again.
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

    /// A reload while the place is already resolving does not ask a second time: nothing was
    /// invalidated, so the flying answer is the current one — and it is what builds the new
    /// attempt's page. Exactly one page comes out either way.
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
