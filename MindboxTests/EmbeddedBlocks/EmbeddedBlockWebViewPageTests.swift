//
//  EmbeddedBlockWebViewPageTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
import WebKit
@_spi(Internal) @testable import Mindbox

/// The page only judges its own business: the load failed or the document arrived. It is exactly
/// this separation that is checked here — and above all, that a cancelled navigation does not end up
/// among the failures.
@Suite("Embedded block web view page", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockWebViewPageTests {

    /// A navigation is cancelled in two perfectly ordinary cases: it was superseded by a client-side
    /// redirect, and it was stopped by our own `cancel()` on a block that went off screen. Neither
    /// means the block is broken — while a failure collapses it for good.
    @Test("A cancelled provisional navigation is not a load failure")
    func cancelledProvisionalNavigationIsNotAFailure() {
        let bed = PageBed()

        bed.failProvisionalNavigation(with: bed.cancellationError)

        #expect(bed.failures == 0)
    }

    /// A real network error, on the other hand, is exactly what the page must report.
    @Test("A real provisional navigation error is a load failure")
    func realProvisionalErrorIsAFailure() {
        let bed = PageBed()

        bed.failProvisionalNavigation(with: bed.error(code: NSURLErrorNotConnectedToInternet))

        #expect(bed.failures == 1)
    }

    /// Cancelling one navigation must not mute the page: the next real error arrives as usual.
    @Test("A cancellation does not swallow the failure that comes after it")
    func cancellationDoesNotSwallowLaterFailures() {
        let bed = PageBed()

        bed.failProvisionalNavigation(with: bed.cancellationError)
        bed.failProvisionalNavigation(with: bed.error(code: NSURLErrorCannotFindHost))

        #expect(bed.failures == 1)
    }

    @Test("A finished document is reported as a finish, not as a failure")
    func finishedDocumentIsReportedAsFinish() {
        let bed = PageBed()

        bed.finishNavigation()

        #expect(bed.finishes == 1)
        #expect(bed.failures == 0)
    }

    // MARK: - Speaking the shared bridge

    /// The bridge drops every script message until the load's own document commits, because a
    /// reused web view can still deliver a previous owner's. Handing it the navigation is what
    /// opens that gate — forget it and the page's messages vanish with no error anywhere.
    ///
    /// > Note: what the bridge was told is not observable from here — `contentLoadIssued` and
    /// > `contentURL` are private to `MindboxWebBridge`, and a `WKScriptMessage` cannot be built in
    /// > a test to drive the gate from the outside. So this pins the half that is visible: the load
    /// > that the registration accompanies actually goes to the block's own address.
    @Test("Loading a url block loads that url")
    func loadingURLContentLoadsThatURL() {
        let bed = PageBed()
        guard case .url(let contentURL) = EmbeddedBlockWebContent.stub.source else {
            Issue.record("the stub stands for a block with an address")
            return
        }

        bed.page.load()

        #expect(bed.page.webView.url == contentURL)
    }

    /// Markup has no address of its own: it is loaded with a nil base URL on purpose, so the page
    /// gets an `about:blank` origin rather than the privileges of some domain.
    @Test("Loading html content gives the page no domain of its own")
    func loadingHTMLContentHasNoOrigin() {
        let bed = PageBed(content: EmbeddedBlockWebContent(html: "<html><body>block</body></html>"))

        bed.page.load()

        #expect(bed.page.webView.url == nil || bed.page.webView.url?.absoluteString == "about:blank")
    }

    // MARK: - Being a host of the shared bridge

    /// The point of the move onto the shared bridge: a request from the page's document reaches the
    /// same registry an in-app show uses, with the page itself as the host.
    @Test("A request from the page is routed into the action registry")
    func requestIsRoutedIntoTheRegistry() throws {
        let owner = RecordingHandler(actions: [.openLink])
        let bed = PageBed(handlers: [owner])
        let message = BridgeMessage.request(.openLink)

        bed.deliver(message)

        #expect(owner.handled.map(\.id) == [message.id])
        #expect(owner.hosts.first === bed.page, "the page hosts its own requests")
    }

    /// Responses and errors are answers to something the SDK asked, and the dispatcher matches them
    /// to their pending request. Routing them as if they were requests would run a handler twice.
    ///
    /// Both kinds in one test rather than as arguments: `MessageType` crossing into a `@MainActor`
    /// suite as a parameter is not `Sendable` enough for the Swift 6 language mode.
    @Test("Anything that is not a request is not routed")
    func nonRequestIsNotRouted() {
        let owner = RecordingHandler(actions: [.openLink])
        let bed = PageBed(handlers: [owner])
        let action = BridgeMessage.Action.openLink.rawValue

        bed.deliver(BridgeMessage(type: .response, action: action, payload: nil))
        bed.deliver(BridgeMessage(type: .error, action: action, payload: nil))

        #expect(owner.handled.isEmpty)
    }

    /// A vocabulary newer than the SDK is allowed: an action nobody owns is journalled and dropped,
    /// not treated as a failure of the block.
    @Test("An action nobody owns is dropped without disturbing the block")
    func unownedActionIsDropped() {
        let bed = PageBed(handlers: [])

        bed.deliver(.request(.openLink))

        #expect(bed.failures == 0)
        #expect(bed.finishes == 0)
    }

    @Test("The block identifies itself by its own id and journals under its own category")
    func hostIdentityIsTheBlocks() {
        let bed = PageBed()

        #expect(bed.page.contentId == "block-id")
        #expect(bed.page.logCategory == .embeddedBlocks)
    }

    /// Tags belong to an in-app show — they are what an operation is attributed to. A block has no
    /// show behind it, so it contributes none.
    @Test("A block carries no in-app tags")
    func hostCarriesNoTags() {
        let bed = PageBed()

        #expect(bed.page.tags == nil)
    }

    /// The provider is what knows whether anyone is looking, and it says so through this. A page
    /// starts out in front of the user because it is built when the block enters the window.
    @Test("A fresh page starts out in front of the user")
    func freshPageStartsPresent() {
        let bed = PageBed()

        #expect(bed.page.isUserPresent)
    }

    @Test("What the provider sets is what the bridge reads")
    func presenceFollowsTheProvider() {
        let bed = PageBed()

        bed.page.isUserPresent = false

        #expect(bed.page.isUserPresent == false)
    }

    /// The block is a piece of the host's own layout, so a tap must not replace the feed with the
    /// destination in place. Links belong in `openLink`.
    @Test("An in-place link navigation is refused")
    func inPlaceLinkNavigationIsRefused() async {
        let bed = PageBed()

        let policy = await bed.decidePolicy(for: .linkActivated)

        #expect(policy == .cancel)
    }

    @Test("The page's own loads are allowed", arguments: [WKNavigationType.other, .reload, .backForward])
    func ownNavigationIsAllowed(type: WKNavigationType) async {
        let bed = PageBed()

        let policy = await bed.decidePolicy(for: type)

        #expect(policy == .allow)
    }

    // MARK: - Presenting from the host's hierarchy

    /// A handler that needs a controller of its own gets the topmost one. The root is not it: a root
    /// that already presents something refuses to present anything else, and UIKit refuses without
    /// calling the completion the answer to the page is sent from.
    @Test("The presenter is the topmost presented controller, not the window root")
    func presenterIsTheTopmostController() {
        let bed = PageBed()
        let modal = StubPresentingController()
        bed.putInWindow(presenting: modal)

        #expect(bed.page.presentingViewController === modal)
    }

    /// A block inside a modal that itself presents a sheet is still the same question, one level
    /// deeper — the walk does not stop at the first answer.
    @Test("The walk goes through the whole presentation chain")
    func presenterIsFoundThroughTheChain() {
        let bed = PageBed()
        let sheet = StubPresentingController()
        let modal = StubPresentingController()
        modal.stubbedPresented = sheet
        bed.putInWindow(presenting: modal)

        #expect(bed.page.presentingViewController === sheet)
    }

    @Test("With nothing presented the root is the presenter")
    func rootIsThePresenterWhenNothingIsPresented() {
        let bed = PageBed()
        bed.putInWindow(presenting: nil)

        #expect(bed.page.presentingViewController === bed.root)
    }

    /// Off the window there is nobody to present from, and the handler answers the page with an
    /// error rather than waiting on a presentation that cannot happen.
    @Test("Off the window there is no presenter")
    func thereIsNoPresenterOffTheWindow() {
        let bed = PageBed()

        #expect(bed.page.presentingViewController == nil)
    }
}

/// Records what the registry routed to it, and which host came with it.
private final class RecordingHandler: WebBridgeActionHandler {

    let actions: Set<BridgeMessage.Action>

    private(set) var handled: [BridgeMessage] = []
    private(set) var hosts: [WebBridgeHost] = []

    init(actions: Set<BridgeMessage.Action>) {
        self.actions = actions
    }

    func handle(_ message: BridgeMessage, host: WebBridgeHost) {
        handled.append(message)
        hosts.append(host)
    }
}

/// Reports whatever the test put on top of it.
///
/// `presentedViewController` is set by an actual presentation, which drags a visible window and a
/// transition into a unit test. What is checked here is the walk, not UIKit's animation.
@MainActor
private final class StubPresentingController: UIViewController {

    var stubbedPresented: UIViewController?

    override var presentedViewController: UIViewController? { stubbedPresented }
}

/// A real page with a real web view, but without the network: the tests call the navigation delegate
/// methods themselves — it is their handling that is checked here.
@MainActor
private final class PageBed {

    let page: EmbeddedBlockWebViewPage

    /// The controller the host's window is rooted at.
    let root = StubPresentingController()

    private(set) var failures = 0
    private(set) var finishes = 0

    var cancellationError: Error { error(code: NSURLErrorCancelled) }

    /// Held on purpose: a window nobody retains takes the page's view out of the hierarchy with it,
    /// and the page would look off screen again.
    private var window: UIWindow?

    /// Through the protocol rather than directly: the page has both a `webView` property and
    /// delegate methods with the same name, so they are better called where the name is unambiguous.
    private var navigation: WebBridgeNavigationDelegate { page }

    private var messages: WebBridgeMessageDelegate { page }

    private let bridge: MindboxWebBridge

    /// - Parameter handlers: the registry the page routes into. Empty by default — a suite that does
    ///   not send anything has no use for the shipped set, and building it here would drag every
    ///   handler's dependencies into tests about navigation.
    init(content: EmbeddedBlockWebContent = .stub, handlers: [WebBridgeActionHandler] = []) {
        let webView = WKWebView()
        bridge = MindboxWebBridge(webView: webView)
        page = EmbeddedBlockWebViewPage(id: "block-id",
                                       content: content,
                                       webView: webView,
                                       actionRegistry: WebBridgeActionRegistry(handlers: handlers))
        page.onLoadFailure = { [weak self] in
            self?.failures += 1
        }
        page.onLoadFinish = { [weak self] in
            self?.finishes += 1
        }
    }

    /// Hands the page a message as the bridge would.
    func deliver(_ message: BridgeMessage) {
        messages.webBridge(bridge, didReceiveBridgeMessage: message)
    }

    /// Puts the page where a real block lives — inside the host's own view hierarchy — with
    /// `presented` standing on top of the window's root.
    func putInWindow(presenting presented: UIViewController?) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        root.stubbedPresented = presented
        window.rootViewController = root
        // Straight onto the window rather than into the root's view: all the page needs is to have
        // a window, and a test window belongs to no scene — it installs its root's view only when
        // it is about to be shown.
        window.addSubview(page.view)
        self.window = window
    }

    func error(code: Int) -> Error {
        NSError(domain: NSURLErrorDomain, code: code)
    }

    func failProvisionalNavigation(with error: Error) {
        navigation.webBridge(bridge, didFailProvisionalNavigation: nil, error: error)
    }

    func finishNavigation() {
        navigation.webBridge(bridge, didFinishNavigation: nil)
    }

    func decidePolicy(for type: WKNavigationType) async -> WKNavigationActionPolicy {
        await withCheckedContinuation { continuation in
            navigation.webBridge(bridge, decidePolicyFor: nil, navigationType: type) {
                continuation.resume(returning: $0)
            }
        }
    }
}
