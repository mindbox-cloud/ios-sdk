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
    @Test("Loading hands the navigation to the bridge")
    func loadRegistersItsNavigation() {
        let bed = PageBed()

        bed.page.load()

        #expect(bed.page.webView.url != nil)
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
}

/// A real page with a real web view, but without the network: the tests call the navigation delegate
/// methods themselves — it is their handling that is checked here.
@MainActor
private final class PageBed {

    let page: EmbeddedBlockWebViewPage

    private(set) var failures = 0
    private(set) var finishes = 0

    var cancellationError: Error { error(code: NSURLErrorCancelled) }

    /// Through the protocol rather than directly: the page has both a `webView` property and
    /// delegate methods with the same name, so they are better called where the name is unambiguous.
    private var navigation: WebBridgeNavigationDelegate { page }

    private let bridge: MindboxWebBridge

    init() {
        let webView = WKWebView()
        bridge = MindboxWebBridge(webView: webView)
        page = EmbeddedBlockWebViewPage(id: "block-id", content: .stub, webView: webView)
        page.onLoadFailure = { [weak self] in
            self?.failures += 1
        }
        page.onLoadFinish = { [weak self] in
            self?.finishes += 1
        }
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
