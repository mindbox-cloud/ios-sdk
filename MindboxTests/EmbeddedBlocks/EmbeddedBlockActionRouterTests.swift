//
//  EmbeddedBlockActionRouterTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("Embedded block action router", .tags(.embeddedBlocks))
struct EmbeddedBlockActionRouterTests {

    // MARK: - openUrl

    @Test("A web address from the page is opened")
    func webAddressIsOpened() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(openUrl("https://mindbox.ru/promo"))

        #expect(opener.openedURLs.map(\.absoluteString) == ["https://mindbox.ru/promo"])
    }

    @Test("Plain http is opened too")
    func httpIsOpened() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(openUrl("http://mindbox.ru"))

        #expect(opener.openedURLs.count == 1)
    }

    /// Диплинк в само это приложение никуда пользователя не увозит, поэтому он разрешён — но только
    /// если хост действительно объявил эту схему своей.
    @Test("A deep link into the host app itself is opened")
    func hostAppDeepLinkIsOpened() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener, hostAppSchemes: ["myshop"])

        router.handle(openUrl("myshop://cart"))

        #expect(opener.openedURLs.count == 1)
    }

    @Test("Scheme matching ignores case")
    func schemeMatchingIgnoresCase() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener, hostAppSchemes: ["myshop"])

        router.handle(openUrl("MyShop://cart"))
        router.handle(openUrl("HTTPS://mindbox.ru"))

        #expect(opener.openedURLs.count == 2)
    }

    // MARK: - Schemes the page may not open

    /// Системное действие — это уже не переход по контенту: страница блока приезжает из сети, и
    /// звонить за пользователя ей не положено.
    @Test("A tel: link from the page is refused")
    func telLinkIsRefused() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(openUrl("tel://+79001234567"))

        #expect(opener.openedURLs.isEmpty)
    }

    @Test("System and third-party app schemes are refused")
    func foreignSchemesAreRefused() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener, hostAppSchemes: ["myshop"])

        for raw in ["sms://+79001234567",
                    "itms-apps://apps.apple.com/app/id1",
                    "app-settings://",
                    "mailto:hi@mindbox.ru",
                    "someotherapp://pay"] {
            router.handle(openUrl(raw))
        }

        #expect(opener.openedURLs.isEmpty)
    }

    /// Схема чужого приложения не становится разрешённой от того, что система умеет её открыть, —
    /// именно это `canOpenURL` и говорит.
    @Test("A refused scheme is not saved by canOpenURL saying yes")
    func canOpenDoesNotOverridePolicy() {
        let opener = EmbeddedBlockURLOpenerMock()
        opener.canOpenAnything = true
        let router = makeRouter(opener: opener)

        router.handle(openUrl("tel://+79001234567"))

        #expect(opener.openedURLs.isEmpty)
    }

    @Test("A url without a scheme is refused")
    func schemelessUrlIsRefused() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(openUrl("mindbox.ru/promo"))

        #expect(opener.openedURLs.isEmpty)
    }

    // MARK: - Malformed actions

    @Test("An allowed url the system cannot open is not opened")
    func unopenableUrlIsNotOpened() {
        let opener = EmbeddedBlockURLOpenerMock()
        opener.canOpenAnything = false
        let router = makeRouter(opener: opener)

        router.handle(openUrl("https://mindbox.ru"))

        #expect(opener.openedURLs.isEmpty)
    }

    @Test("openUrl without a url payload opens nothing")
    func missingUrlOpensNothing() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(EmbeddedBlockPageAction(type: "openUrl", payload: ["type": "openUrl"]))

        #expect(opener.openedURLs.isEmpty)
    }

    @Test("openUrl with a non-string url opens nothing")
    func nonStringUrlOpensNothing() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(EmbeddedBlockPageAction(type: "openUrl", payload: ["url": 42]))

        #expect(opener.openedURLs.isEmpty)
    }

    /// Словарь у веб-стороны может быть новее, чем у SDK: незнакомое действие — не ошибка.
    @Test("An unknown action is ignored without side effects")
    func unknownActionIsIgnored() {
        let opener = EmbeddedBlockURLOpenerMock()
        let router = makeRouter(opener: opener)

        router.handle(EmbeddedBlockPageAction(type: "shareSomethingNew", payload: ["url": "https://mindbox.ru"]))

        #expect(opener.openedURLs.isEmpty)
    }

    // MARK: - Host app schemes

    @Test("Every scheme of every declared url type counts as the host's own")
    func allDeclaredSchemesAreCollected() {
        let info: [String: Any] = [
            "CFBundleURLTypes": [
                ["CFBundleURLName": "main", "CFBundleURLSchemes": ["MyShop", "myshop-dev"]],
                ["CFBundleURLName": "legacy", "CFBundleURLSchemes": ["oldshop"]]
            ]
        ]

        let schemes = EmbeddedBlockActionRouter.hostAppSchemes(in: info)

        #expect(schemes == ["myshop", "myshop-dev", "oldshop"])
    }

    /// Хост может не объявлять схем вообще, а объявленное — быть неполным: разбор Info.plist не
    /// должен ни падать, ни придумывать схемы, которых там нет.
    @Test("A missing or malformed CFBundleURLTypes yields no schemes")
    func malformedBundleYieldsNoSchemes() {
        #expect(EmbeddedBlockActionRouter.hostAppSchemes(in: nil).isEmpty)
        #expect(EmbeddedBlockActionRouter.hostAppSchemes(in: [:]).isEmpty)
        #expect(EmbeddedBlockActionRouter.hostAppSchemes(in: ["CFBundleURLTypes": "myshop"]).isEmpty)
        #expect(EmbeddedBlockActionRouter.hostAppSchemes(in: ["CFBundleURLTypes": [["CFBundleURLName": "main"]]]).isEmpty)
    }

    // MARK: - Helpers

    private func makeRouter(opener: EmbeddedBlockURLOpening,
                            hostAppSchemes: Set<String> = []) -> EmbeddedBlockActionRouter {
        EmbeddedBlockActionRouter(urlOpener: opener, hostAppSchemes: hostAppSchemes)
    }

    private func openUrl(_ raw: String) -> EmbeddedBlockPageAction {
        EmbeddedBlockPageAction(type: "openUrl", payload: ["type": "openUrl", "url": raw])
    }
}
