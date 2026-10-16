//
//  EmbeddedBlockReleaseTests.swift
//  MindboxTests
//
//  Created by vailence on 14.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import SwiftUI
import UIKit
import WebKit
@_spi(Internal) @testable import Mindbox

/// The whole web chain of a block — container, provider, page, facade, WKWebView and bridge —
/// must go when the block does, whatever it was doing. No mocks on the web side: the markup
/// comes from a `data:` URL, so nothing touches the network.
@Suite("Embedded block release, real web chain", .tags(.embeddedBlocks), .serialized)
@MainActor
struct EmbeddedBlockReleaseTests {

    @Test("A block let go while its page is still loading is released whole")
    func blockLetGoMidLoadIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await settle(0.1)
        }

        chain.expectReleased()
    }

    @Test("A block let go after its page rendered is released whole")
    func blockLetGoAfterReadyIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await block.waitUntilLoaded()
            #expect(chain.pagesInRegistry == 1, "a booted page joins the registry")
        }

        chain.expectReleased()
    }

    @Test("A block let go after a reload is released, the dropped page with it")
    func blockLetGoAfterReloadIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await block.waitUntilLoaded()
            block.reload()
            await settle(0.1)
        }

        chain.expectReleased()
        #expect(chain.pagesBuilt == 2)
    }

    @Test("A block whose page stayed silent until the timeout is released whole")
    func blockTimedOutIsReleased() async {
        let chain = Chain(reports: false)

        await chain.exercise { block in
            block.attach()
            await settle(0.3)
            block.waitBudget.scheduler.fireAll()
            await settle(0.1)
            #expect(block.outcomes.events == [.failed(.internalError)])
        }

        chain.expectReleased()
    }

    @Test("A block dismantled by SwiftUI is released whole")
    func blockDismantledBySwiftUIIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            let coordinator = EmbeddedBlockRepresentable.Coordinator(appearance: .constant(nil),
                                                                     onLoad: nil, onEmpty: nil, onFail: nil)
            block.view.delegate = coordinator
            EmbeddedBlockRepresentable.observe(block.view, with: coordinator)
            block.attach()
            await settle(0.5)
            EmbeddedBlockRepresentable.dismantleUIView(block.view, coordinator: coordinator)
        }

        chain.expectReleased()
    }

    @Test("A block reloaded many times in a row is released, every dropped page with it")
    func blockReloadedInAStormIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await block.waitUntilLoaded()
            for _ in 0..<10 {
                block.reload()
                await settle(0.05)
            }
            await settle(0.5)
        }

        chain.expectReleased()
        #expect(chain.pagesBuilt == 11)
    }

    @Test("A block let go with a data push still unconfirmed is released whole")
    func blockLetGoDuringADataPushIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await block.waitUntilLoaded()
            await chain.pushNewData()
        }

        chain.expectReleased()
        // The same page was told about its data, not rebuilt.
        #expect(chain.pagesBuilt == 1)
    }

    @Test("A block that went to the background and came back is released whole")
    func blockAfterBackgroundRoundTripIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await block.waitUntilLoaded()
            chain.presenceBed.enterBackground()
            await settle(0.2)
            chain.presenceBed.returnToApp()
            chain.presenceBed.finishSessionCheck()
            await settle(0.2)
        }

        chain.expectReleased()
    }

    @Test("Blocks created and dropped in a row leave nothing behind")
    func repeatedBlocksLeaveNothingBehind() async {
        let chain = Chain()

        for _ in 0..<20 {
            await chain.exercise { block in
                block.attach()
                await settle(0.05)
            }
        }

        chain.expectReleased()
        #expect(chain.pagesBuilt == 20)
    }
}

// MARK: - The chain

/// Everything behind one block, held weakly once the block is let go.
@MainActor
private final class Chain {

    private struct HeldBlock {
        weak var view: MindboxEmbeddedBlockView?
        weak var provider: EmbeddedBlockWebViewProvider?
    }

    /// Taken as each page is built: a page dropped by a reload must go as well as the last one.
    private struct HeldPage {
        weak var page: EmbeddedBlockWebViewPage?
        weak var facade: MindboxWebViewFacade?
        weak var webView: WKWebView?
        weak var bridge: MindboxWebBridge?

        init(_ page: EmbeddedBlockWebViewPage) {
            self.page = page
            let facade = page.facade as? MindboxWebViewFacade
            self.facade = facade
            webView = facade?.makeView() as? WKWebView
            bridge = facade?.bridge
        }

        var isReleased: Bool { page == nil && facade == nil && webView == nil && bridge == nil }
    }

    @MainActor
    final class Block {
        let view: MindboxEmbeddedBlockView
        let outcomes = EmbeddedBlockViewDelegateMock()
        let waitBudget: EmbeddedBlockWaitBudgetBed
        private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        init(view: MindboxEmbeddedBlockView, waitBudget: EmbeddedBlockWaitBudgetBed) {
            self.view = view
            self.waitBudget = waitBudget
            view.delegate = outcomes
        }

        func reload() {
            view.reload()
        }

        func attach() {
            window.isHidden = false
            window.addSubview(view)
        }

        /// Up to 20 s: the first page of a run waits for WebKit's content process to start, over 2 s
        /// on a laptop and past 3 s on CI.
        func waitUntilLoaded() async {
            for _ in 0..<400 where outcomes.events.isEmpty {
                await settle(0.05)
            }
            #expect(outcomes.events == [.loaded])
        }

        func detach() {
            view.removeFromSuperview()
            window.isHidden = true
        }
    }

    private let pageRegistry = MindboxWebPageRegistry()
    let resolver: EmbeddedBlockResolverMock
    /// The registry's own center: a new config is announced here, nothing else hears it.
    let center = NotificationCenter()
    /// The app's presence as this chain sees it: the shared one would carry the background round
    /// trip of one test into every block built after it.
    let presenceBed: AppPresenceBed
    private let placeRegistry: EmbeddedBlockPlaceRegistry
    private var lastPage: EmbeddedBlockWebViewPage?
    private(set) var pagesBuilt = 0
    var pagesInRegistry: Int { pageRegistry.count }
    private var heldBlocks: [HeldBlock] = []
    private var heldPages: [HeldPage] = []

    /// `reports: false` — a page that never says anything, for the timeout.
    init(reports: Bool = true) {
        TestConfiguration.configure()
        resolver = EmbeddedBlockResolverMock(resolution: .content(Self.content(reports: reports)))
        presenceBed = AppPresenceBed(center: center)
        placeRegistry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                   budget: InappShowBudgetMock(),
                                                   notificationCenter: center,
                                                   fetchEmbeddedPlaces: { $0(nil) },
                                                   presence: presenceBed.presence)
    }

    /// Builds a block, hands it to `body`, lets it go and waits for WebKit to catch up.
    func exercise(_ body: (Block) async -> Void) async {
        let waitBudget = EmbeddedBlockWaitBudgetBed()
        var held = HeldBlock()

        do {
            let provider = EmbeddedBlockWebViewProvider(placeSystemName: "release-test",
                                                        registry: placeRegistry,
                                                        inappService: InappRequestServiceMock(),
                                                        makePage: { [unowned self] content in
                                                            let page = EmbeddedBlockWebViewPage(content: content,
                                                                                                registry: pageRegistry)
                                                            pagesBuilt += 1
                                                            heldPages.append(HeldPage(page))
                                                            lastPage = page
                                                            return page
                                                        },
                                                        accounting: InappShowAccountingMock(),
                                                        reportFailure: { _, _, _, _ in },
                                                        reportUnansweredWait: { _ in },
                                                        appPresence: presenceBed.presence)
            let view = MindboxEmbeddedBlockView(placeSystemName: "release-test",
                                                height: 120,
                                                contentProvider: provider,
                                                placeMemory: EmbeddedBlockPlaceMemoryMock(),
                                                loadingStrategy: .placeholder,
                                                makeWaitBudget: { _, _ in waitBudget.budget })
            let block = Block(view: view, waitBudget: waitBudget)
            await body(block)

            held.view = view
            held.provider = provider
            lastPage = nil
            block.detach()
        }

        heldBlocks.append(held)
        await waitForRelease()
    }

    /// WebKit lets its objects go on later turns of the main queue; up to 5 s for it to catch up.
    private func waitForRelease() async {
        for _ in 0..<100 where !isReleased {
            await settle(0.05)
        }
    }

    private var isReleased: Bool {
        heldBlocks.allSatisfy { $0.view == nil && $0.provider == nil } && heldPages.allSatisfy(\.isReleased)
    }

    func expectReleased() {
        for (index, block) in heldBlocks.enumerated() {
            #expect(block.view == nil, "block \(index): container alive")
            #expect(block.provider == nil, "block \(index): provider alive")
        }
        for (index, page) in heldPages.enumerated() {
            #expect(page.page == nil, "page \(index): page alive")
            #expect(page.facade == nil, "page \(index): facade alive")
            #expect(page.webView == nil, "page \(index): WKWebView alive")
            #expect(page.bridge == nil, "page \(index): bridge alive")
        }
        #expect(pagesInRegistry == 0, "pages left in the registry")
    }

    /// The same page with new params, announced as a new config: what a changed config pushes into
    /// a live page. Waits until the page hears of it — it never confirms.
    func pushNewData() async {
        let content = Self.content(reports: true)
        resolver.resolution = .content(EmbeddedBlockWebContent(inAppId: content.inAppId,
                                                               baseUrl: content.baseUrl,
                                                               contentUrl: content.contentUrl,
                                                               frequency: content.frequency,
                                                               tags: content.tags,
                                                               params: ["pushed": .bool(true)]))
        center.post(name: .mobileConfigDownloadConcluded,
                    object: nil,
                    userInfo: [Constants.Notification.configVersion: resolver.publishConfig()])

        var heard: [String] = []
        for _ in 0..<100 where !heard.contains(BridgeMessage.Action.initDataUpdated.rawValue) {
            await settle(0.05)
            heard = await actionsHeardByLastPage()
        }
        #expect(heard.contains(BridgeMessage.Action.initDataUpdated.rawValue))
    }

    private func actionsHeardByLastPage() async -> [String] {
        guard let facade = lastPage?.facade else { return [] }

        return await withCheckedContinuation { continuation in
            facade.evaluateJavaScript("window.heard || []") { result in
                continuation.resume(returning: (try? result.get()) as? [String] ?? [])
            }
        }
    }

    /// A page served from a `data:` URL that boots, writes down every action the SDK sends it and
    /// reports one rendered item on its own — or a page that says nothing at all.
    static func content(reports: Bool) -> EmbeddedBlockWebContent {
        let handler = "window.webkit.messageHandlers.\(Constants.WebViewBridgeJS.handlerName)"
        let script = """
        <script>
        window.heard = [];
        window.bridgeMessagesHandlers = {emit: function (json) { window.heard.push(JSON.parse(json).action); }};
        function request(action, payload, id) {
            \(handler).postMessage(JSON.stringify({version: 1, type: "request", action: action,
                                                  payload: JSON.stringify(payload), id: id, timestamp: Date.now()}));
        }
        request("ready", {}, "6F9619FF-8B86-D011-B42D-00C04FC964FE");
        request("contentRendered", {count: 1}, "6F9619FF-8B86-D011-B42D-00C04FC964FF");
        </script>
        """
        let html = "<!doctype html><html><body>release test\(reports ? script : "")</body></html>"
        let encoded = Data(html.utf8).base64EncodedString()
        return EmbeddedBlockWebContent(inAppId: "release-inapp",
                                       baseUrl: "https://inapp.local/release",
                                       contentUrl: "data:text/html;base64,\(encoded)",
                                       frequency: .unlimited,
                                       tags: nil,
                                       params: [:])
    }
}

/// Yields the main actor: the main queue drains the block's deliveries and WebKit's callbacks,
/// and WebKit releases its objects there. A nested run loop would not do — the test itself is a
/// main-queue job, and the main queue does not re-enter.
@MainActor
private func settle(_ seconds: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}
