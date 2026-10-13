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
        }

        chain.expectReleased()
    }

    @Test("A block let go after a reload is released, the dropped page with it")
    func blockLetGoAfterReloadIsReleased() async {
        let chain = Chain()

        await chain.exercise { block in
            block.attach()
            await block.waitUntilLoaded()
            block.view.reload()
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
            #expect(block.delegate.events == [.failed(.internalError)])
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

    private struct Held {
        weak var view: MindboxEmbeddedBlockView?
        weak var provider: EmbeddedBlockWebViewProvider?
        weak var page: EmbeddedBlockWebViewPage?
        weak var facade: MindboxWebViewFacade?
        weak var webView: WKWebView?
        weak var bridge: MindboxWebBridge?
    }

    @MainActor
    final class Block {
        let view: MindboxEmbeddedBlockView
        let delegate = EmbeddedBlockViewDelegateMock()
        let waitBudget: EmbeddedBlockWaitBudgetBed
        private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        init(view: MindboxEmbeddedBlockView, waitBudget: EmbeddedBlockWaitBudgetBed) {
            self.view = view
            self.waitBudget = waitBudget
            view.delegate = delegate
        }

        func attach() {
            window.isHidden = false
            window.addSubview(view)
        }

        func waitUntilLoaded() async {
            for _ in 0..<60 where delegate.events.isEmpty {
                await settle(0.05)
            }
            #expect(delegate.events == [.loaded])
        }

        func detach() {
            view.removeFromSuperview()
            window.isHidden = true
        }
    }

    private let pageRegistry = MindboxWebPageRegistry()
    private let resolver: EmbeddedBlockResolverMock
    private let placeRegistry: EmbeddedBlockPlaceRegistry
    private var lastPage: EmbeddedBlockWebViewPage?
    private(set) var pagesBuilt = 0
    private var held: [Held] = []

    /// `reports: false` — a page that never says anything, for the timeout.
    init(reports: Bool = true) {
        TestConfiguration.configure()
        resolver = EmbeddedBlockResolverMock(resolution: .content(Self.content(reports: reports)))
        placeRegistry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                   budget: InappShowBudgetMock(),
                                                   notificationCenter: NotificationCenter(),
                                                   fetchEmbeddedPlaces: { $0(nil) })
    }

    /// Builds a block, hands it to `body`, lets it go and waits for WebKit to catch up.
    func exercise(_ body: (Block) async -> Void) async {
        let waitBudget = EmbeddedBlockWaitBudgetBed()
        var snapshot = Held()

        do {
            let provider = EmbeddedBlockWebViewProvider(placeSystemName: "release-test",
                                                        registry: placeRegistry,
                                                        inappService: InappRequestServiceMock(),
                                                        makePage: { [unowned self] content in
                                                            let page = EmbeddedBlockWebViewPage(content: content,
                                                                                                registry: pageRegistry)
                                                            pagesBuilt += 1
                                                            lastPage = page
                                                            return page
                                                        },
                                                        accounting: InappShowAccountingMock(),
                                                        reportFailure: { _, _, _, _ in },
                                                        reportUnansweredWait: { _ in })
            let view = MindboxEmbeddedBlockView(placeSystemName: "release-test",
                                                height: 120,
                                                contentProvider: provider,
                                                placeMemory: EmbeddedBlockPlaceMemoryMock(),
                                                loadingStrategy: .placeholder,
                                                makeWaitBudget: { _, _ in waitBudget.budget })
            let block = Block(view: view, waitBudget: waitBudget)
            await body(block)

            snapshot.view = view
            snapshot.provider = provider
            if let page = lastPage {
                snapshot.page = page
                let facade = page.facade as? MindboxWebViewFacade
                snapshot.facade = facade
                snapshot.webView = facade?.makeView() as? WKWebView
                snapshot.bridge = facade?.bridge
            }
            lastPage = nil
            block.detach()
        }

        held.append(snapshot)
        await settle(0.3)
    }

    func expectReleased() {
        for (index, chain) in held.enumerated() {
            #expect(chain.view == nil, "block \(index): container alive")
            #expect(chain.provider == nil, "block \(index): provider alive")
            #expect(chain.page == nil, "block \(index): page alive")
            #expect(chain.facade == nil, "block \(index): facade alive")
            #expect(chain.webView == nil, "block \(index): WKWebView alive")
            #expect(chain.bridge == nil, "block \(index): bridge alive")
        }
        #expect(pageRegistry.count == 0)
    }

    /// A page served from a `data:` URL that reports one rendered item on its own, or nothing.
    private static func content(reports: Bool) -> EmbeddedBlockWebContent {
        let report = """
        <script>
        var message = {version: 1, type: "request", action: "contentRendered",
                       payload: JSON.stringify({count: 1}),
                       id: "6F9619FF-8B86-D011-B42D-00C04FC964FF", timestamp: Date.now()};
        window.webkit.messageHandlers.\(Constants.WebViewBridgeJS.handlerName).postMessage(JSON.stringify(message));
        </script>
        """
        let html = "<!doctype html><html><body>release test\(reports ? report : "")</body></html>"
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
