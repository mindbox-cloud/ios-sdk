//
//  EmbeddedBlockWebViewPageTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import WebKit
@_spi(Internal) @testable import Mindbox

/// The page sits between the shared web layer and the block, and its whole job is deciding who owns
/// an incoming message: the one response the provider waits on is caught first, everything else is
/// the shared action registry's. What is checked here is that division — plus the one navigation
/// judgement the page makes on its own: a cancelled load is not a failure.
@Suite("Embedded block web view page", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWebViewPageTests {

    // MARK: - Navigation

    /// A navigation is cancelled in two perfectly ordinary cases: it was superseded by a client-side
    /// redirect, and it was stopped by our own `cancel()` on a block that went off screen. Neither
    /// means the block is broken — while a failure collapses it for good.
    @Test("A cancelled navigation is not a load failure")
    func cancelledNavigationIsNotAFailure() {
        let bed = PageBed()

        bed.failNavigation(with: bed.error(code: NSURLErrorCancelled))

        #expect(bed.failures == 0)
    }

    /// A real network error, on the other hand, is exactly what the page must report.
    @Test("A real navigation error is a load failure", arguments: [NSURLErrorNotConnectedToInternet,
                                                                  NSURLErrorTimedOut,
                                                                  NSURLErrorCannotFindHost])
    func realNavigationErrorIsAFailure(code: Int) {
        let bed = PageBed()

        bed.failNavigation(with: bed.error(code: code))

        #expect(bed.failures == 1)
    }

    /// Cancelling one navigation must not mute the page: the next real error arrives as usual.
    @Test("A cancellation does not swallow the failure that comes after it")
    func cancellationDoesNotSwallowLaterFailures() {
        let bed = PageBed()

        bed.failNavigation(with: bed.error(code: NSURLErrorCancelled))
        bed.failNavigation(with: bed.error(code: NSURLErrorCannotFindHost))

        #expect(bed.failures == 1)
    }

    /// The push the page makes when its config changed. Asserted through the facade because that is where
    /// a signature that drifts from the protocol requirement would turn the call into a silent no-op.
    @Test("New init data reaches the web layer")
    func initDataReachesTheWebLayer() {
        let bed = PageBed()

        bed.page.sendInitData(params: ["stories": .string("fresh")])

        #expect(bed.facade.initDataPushes == [["stories": .string("fresh")]])
    }

    @Test("A finished document is not a failure")
    func finishedDocumentIsNotAFailure() {
        let bed = PageBed()

        bed.finishNavigation()

        #expect(bed.failures == 0)
    }

    /// A failure while fetching the markup never reaches navigation at all — there is nothing to
    /// navigate to — so the load's own failure path has to report it.
    @Test("A markup fetch failure fails the block")
    func markupFetchFailureFailsTheBlock() {
        let bed = PageBed()

        bed.page.load()
        bed.facade.failLoad()

        #expect(bed.facade.loads.map(\.contentUrl) == [EmbeddedBlockWebContent.stub.contentUrl])
        #expect(bed.failures == 1)
    }

    /// The content load is ours to perform; a navigation the user started is the page's to decide.
    /// A block that followed a link would replace a feed inside someone's list with a web page.
    @Test("A user-started navigation is blocked and handed back to the page")
    func userStartedNavigationIsBlocked() {
        let bed = PageBed()

        let policy = bed.decidePolicy(for: URL(string: "https://mindbox.ru")!, type: .linkActivated)

        #expect(policy == .cancel)
        #expect(bed.facade.sentActions == [BridgeMessage.Action.navigationIntercepted.rawValue])
    }

    @Test("The content load itself is allowed", arguments: [WKNavigationType.other,
                                                            .reload,
                                                            .backForward])
    func contentLoadIsAllowed(type: WKNavigationType) {
        let bed = PageBed()

        let policy = bed.decidePolicy(for: URL(string: "https://mindbox.ru")!, type: type)

        #expect(policy == .allow)
        #expect(bed.facade.sentActions.isEmpty)
    }

    // MARK: - Who owns a message

    /// `ready` is answered by the shared handler with the start payload the web layer builds — the
    /// same answer a block and an overlay get, because the payload is where the difference lives.
    @Test("Ready is answered with the start payload under the request's own id")
    func readyIsAnsweredWithTheStartPayload() throws {
        let bed = PageBed()

        let ready = BridgeMessage.pageRequest(.ready)
        bed.receive(ready)

        #expect(bed.facade.startPayloadRequests == 1)
        let answer = try #require(bed.facade.sentMessages.first)
        #expect(answer.type == .response)
        #expect(answer.id == ready.id)
    }

    /// A page joins the broadcast set once it has proven it can receive. Registering earlier would
    /// aim `localState.changed` at a document with no bridge yet.
    @Test("A page joins the broadcast set on its first ready, once")
    func pageJoinsTheBroadcastSetOnReady() {
        let registry = MindboxWebPageRegistry()
        let bed = PageBed(registry: registry)

        #expect(registry.count == 0)

        bed.receive(.pageRequest(.ready))
        bed.receive(.pageRequest(.ready))

        #expect(registry.count == 1)
    }

    /// The feed's question travels through the shared registry into the block's capability, and the
    /// answer goes back out under the request's own id.
    @Test("The feed's question reaches the block and the answer goes back to the page")
    func feedQuestionReachesTheBlock() throws {
        let bed = PageBed()

        let question = BridgeMessage.pageRequest(.checkInappsTargeting,
                                                 ["inappIds": .array([.string("one"), .string("two")])])
        bed.receive(question)

        #expect(bed.feedQuestions == [["one", "two"]])

        bed.answerFeed(["one"])

        let answer = try #require(bed.facade.sentMessages.first)
        #expect(answer.type == .response)
        #expect(answer.id == question.id)
        #expect(answer.payload == .object(["inappIds": .array([.string("one")])]))
    }

    @Test("A render report reaches the block with its count")
    func renderReportReachesTheBlock() {
        let bed = PageBed()

        bed.receive(.pageRequest(.contentRendered, ["count": .int(4)]))

        #expect(bed.renderedCounts == [4])
    }

    /// The page was refused, and the block hears it through its own channel: for the surface this is
    /// a failed show, not a page-side detail.
    @Test("An unreadable render report reaches the block as such")
    func unreadableRenderReportReachesTheBlock() {
        let bed = PageBed()

        bed.receive(.pageRequest(.contentRendered))

        #expect(bed.renderedCounts.isEmpty)
        #expect(bed.unreadableReports == 1)
        #expect(bed.facade.sentMessages.map(\.type) == [.error])
    }

    @Test("A show request reaches the block with its params")
    func showRequestReachesTheBlock() throws {
        let bed = PageBed()

        bed.receive(.pageRequest(.showInApp, ["inappId": .string("story-1"),
                                              "params": .object(["k": .string("v")])]))

        let request = try #require(bed.showRequests.first)
        #expect(request.id == "story-1")
        #expect(request.params == ["k": .string("v")])
        #expect(bed.facade.sentMessages.map(\.type) == [.response])
    }

    /// The registry's presence gate, on the block: a page that left the window keeps talking, but
    /// nothing that acts on the user's behalf may run on it — the request is answered with an error
    /// instead of hanging.
    @Test("A show request from a page nobody is looking at is refused")
    func showRequestWithoutUserIsRefused() {
        let bed = PageBed()
        bed.page.isUserPresent = false

        bed.receive(.pageRequest(.showInApp, ["inappId": .string("story-1")]))

        #expect(bed.showRequests.isEmpty)
        #expect(bed.facade.sentMessages.map(\.type) == [.error])
    }

    // MARK: - The provider's one response

    /// The page's answer to the `initDataUpdated` we pushed is the single response the SDK acts on.
    /// It is caught before the registry — which swallows every non-request — and handed to the block.
    @Test("The data push's confirmation is caught before the registry")
    func dataPushConfirmationReachesTheBlock() {
        let bed = PageBed()

        bed.receive(BridgeMessage(type: .response,
                                  action: .initDataUpdated,
                                  payload: .object(["success": .bool(true)])))

        #expect(bed.ackCount == 1)
        #expect(bed.facade.sentMessages.isEmpty)
    }

    /// Every other response is somebody's confirmed request — the registry's to swallow, nobody's
    /// to answer.
    @Test("Another response is swallowed in silence")
    func foreignResponseIsSwallowed() {
        let bed = PageBed()

        bed.receive(BridgeMessage(type: .response, action: .log, payload: .object(["success": .bool(true)])))

        #expect(bed.ackCount == 0)
        #expect(bed.facade.sentMessages.isEmpty)
    }

    /// An overlay's window lifecycle has no meaning for a block: the block hosts no lifecycle, so
    /// the shared handler journals the message and drops it. The dispatcher's blanket success is
    /// the only reply such an action ever gets — nothing extra is sent from here.
    @Test("An overlay's lifecycle message is dropped without an extra answer",
          arguments: [BridgeMessage.Action.close, .`init`, .click, .hide])
    func overlayLifecycleMessageIsDropped(action: BridgeMessage.Action) {
        let bed = PageBed()

        bed.receive(.pageRequest(action))

        #expect(bed.facade.sentMessages.isEmpty)
    }

    /// What the port bought the block: the shared vocabulary is served by the shared handlers now.
    /// Local state is the proof — the same handler, the same answer an overlay gets. The storage is
    /// in memory only because the test container does not carry the real one.
    @Test("A shared action is served by the shared handlers")
    func sharedActionIsServed() throws {
        let handlers: [WebBridgeActionHandler] = [
            LocalStateActionHandler(makeStorage: { EphemeralLocalStateStorage() },
                                    webPageRegistry: MindboxWebPageRegistry())
        ]
        let bed = PageBed(actionRegistry: WebBridgeActionRegistry(handlers: handlers))

        let request = BridgeMessage.pageRequest(.localStateGet, ["data": .array([])])
        bed.receive(request)

        let answer = try #require(bed.facade.sentMessages.first)
        #expect(answer.type == .response)
        #expect(answer.id == request.id)
    }

    @Test("An action nobody knows is not answered")
    func unknownActionIsNotAnswered() {
        let bed = PageBed()

        bed.receive(BridgeMessage(type: .request, action: "somethingNobodyDefined", payload: .string("{}")))

        #expect(bed.facade.sentMessages.isEmpty)
    }

    // MARK: - Pushing

    @Test("A push reaches the page as a request it has to answer")
    func pushIsARequest() {
        let bed = PageBed()

        bed.page.push(.localStateChanged, payload: .object(["version": .int(3)]))

        #expect(bed.facade.sentMessages.map(\.type) == [.request])
        #expect(bed.facade.sentActions == [BridgeMessage.Action.localStateChanged.rawValue])
    }

    // MARK: - Healing a poisoned cache

    /// The overlay path's heal, on the block too: a script that keeps failing over a stale cache entry
    /// is refetched once with the cache bypassed, before the page ever booted.
    @Test("A failing script is retried with the cache bypassed")
    func subresourceErrorHealsThePoisonedCache() {
        let bed = PageBed()

        bed.reportSubresourceError(url: "https://cdn.example/feed.js")

        #expect(bed.facade.cacheBypassingRetries == ["https://cdn.example/feed.js"])
    }

    /// A page whose bridge already spoke can fail a request for its own reasons — that is not a
    /// poisoned boot, and reloading it would throw away a live document.
    @Test("A booted page is not healed")
    func bootedPageIsNotHealed() {
        let bed = PageBed()

        bed.receive(.pageRequest(.ready))
        bed.reportSubresourceError(url: "https://cdn.example/feed.js")

        #expect(bed.facade.cacheBypassingRetries.isEmpty)
    }

    /// Only a script resource marks the cache as suspect — an image failing is an image failing.
    @Test("A non-script subresource error is not healed")
    func nonScriptErrorIsNotHealed() {
        let bed = PageBed()

        bed.reportSubresourceError(url: "https://cdn.example/banner.png")

        #expect(bed.facade.cacheBypassingRetries.isEmpty)
    }

    /// The kill switch kills the heal too: bypassing a cache the feature does not own would be a
    /// silent second fetch on every flaky network.
    @Test("The heal respects the cache kill switch")
    func healRespectsTheKillSwitch() {
        let bed = PageBed(isCacheFeatureEnabled: false)

        bed.reportSubresourceError(url: "https://cdn.example/feed.js")

        #expect(bed.facade.cacheBypassingRetries.isEmpty)
    }
}

/// A real page on a substituted web layer: nothing loads, and every message the page sends is
/// recorded. The bridge is real because the delegate methods are typed on it, but it does no work.
/// The action registry is the real one with the real handler set — the dispatch under test is
/// exactly the dispatch that ships.
@MainActor
private final class PageBed {

    let page: EmbeddedBlockWebViewPage
    let facade = SharedWebLayerMock()

    private(set) var failures = 0
    private(set) var feedQuestions: [[String]] = []
    private(set) var renderedCounts: [Int] = []
    private(set) var unreadableReports = 0
    private(set) var showRequests: [(id: String, params: [String: JSONValue])] = []
    private(set) var ackCount = 0

    private var feedCompletions: [([String]) -> Void] = []

    private lazy var bridge = MindboxWebBridge(webView: facade.webView)

    init(registry: MindboxWebPageRegistry = MindboxWebPageRegistry(),
         actionRegistry: WebBridgeActionRegistry
         = WebBridgeActionRegistry(handlers: WebBridgeActionHandlerFactory.makeHandlers()),
         isCacheFeatureEnabled: Bool = true) {
        TestConfiguration.configure()

        page = EmbeddedBlockWebViewPage(content: .stub,
                                        facade: facade,
                                        registry: registry,
                                        actionRegistry: actionRegistry,
                                        noCacheRetryPolicy: WebViewNoCacheRetryPolicy { isCacheFeatureEnabled })
        page.onLoadFailure = { [weak self] in
            self?.failures += 1
        }
        page.onFeedQuestion = { [weak self] ids, completion in
            self?.feedQuestions.append(ids)
            self?.feedCompletions.append(completion)
        }
        page.onContentRendered = { [weak self] count in
            self?.renderedCounts.append(count)
        }
        page.onUnreadableContentReport = { [weak self] in
            self?.unreadableReports += 1
        }
        page.onShowInAppRequest = { [weak self] id, params in
            self?.showRequests.append((id, params))
        }
        page.onDataPushConfirmed = { [weak self] in
            self?.ackCount += 1
        }
    }

    func error(code: Int) -> Error {
        NSError(domain: NSURLErrorDomain, code: code)
    }

    func receive(_ message: BridgeMessage) {
        facade.messageDelegate?.webBridge(bridge, didReceiveBridgeMessage: message)
    }

    /// The selection answering the feed's question — from wherever it finished.
    func answerFeed(_ allowed: [String]) {
        feedCompletions.forEach { $0(allowed) }
        feedCompletions = []
    }

    func reportSubresourceError(url: String?) {
        facade.navigationDelegate?.webBridge(bridge, didReceiveHTTPError: url)
    }

    func failNavigation(with error: Error) {
        facade.navigationDelegate?.webBridge(bridge, didFailProvisionalNavigation: nil, error: error)
    }

    func finishNavigation() {
        facade.navigationDelegate?.webBridge(bridge, didFinishNavigation: nil)
    }

    func decidePolicy(for url: URL, type: WKNavigationType) -> WKNavigationActionPolicy? {
        var decision: WKNavigationActionPolicy?
        facade.navigationDelegate?.webBridge(bridge, decidePolicyFor: url, navigationType: type) { decision = $0 }
        return decision
    }
}

private final class EphemeralLocalStateStorage: WebViewLocalStateStorageProtocol {

    private var version = 1
    private var storage: [String: String] = [:]

    func get(keys: [String]) -> WebViewLocalState {
        let data = keys.isEmpty ? storage : storage.filter { keys.contains($0.key) }
        return WebViewLocalState(version: version, data: data)
    }

    func set(data: [String: String?]) -> WebViewLocalState {
        apply(data)
        return WebViewLocalState(version: version, data: storage.filter { data.keys.contains($0.key) })
    }

    func initialize(version: Int, data: [String: String?]) -> WebViewLocalState? {
        guard version > 0 else { return nil }

        self.version = version
        apply(data)
        return WebViewLocalState(version: version, data: storage.filter { data.keys.contains($0.key) })
    }

    private func apply(_ data: [String: String?]) {
        for (key, value) in data {
            if let value {
                storage[key] = value
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }
}
