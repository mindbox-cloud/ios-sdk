//
//  EmbeddedBlockContentProviderFactoryTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("Embedded block content provider factory", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockContentProviderFactoryTests {

    @Test("Every call makes its own provider")
    func eachCallMakesItsOwnProvider() {
        let place = "factory-independent-blocks"
        let factory = makeFactory()

        let first = factory.makeProvider(placeSystemName: place)
        let second = factory.makeProvider(placeSystemName: place)

        #expect(first !== second)
    }

    @Test("The provider pulls the requested place through the shared registry")
    func providerPullsThroughTheSharedRegistry() {
        let resolver = EmbeddedBlockResolverMock(resolution: .empty)
        let registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  notificationCenter: NotificationCenter(),
                                                  fetchEmbeddedPlaces: { $0(nil) })
        let factory = EmbeddedBlockContentProviderFactory(registry: registry,
                                                          inappService: EmbeddedBlockInappServiceMock(),
                                                          failureManager: InappShowFailureManagerMock(),
                                                          accounting: InappShowAccountingMock())

        let provider = factory.makeProvider(placeSystemName: "factory-shared-registry")
        withExtendedLifetime(provider) {
            provider.start()
        }

        #expect(resolver.resolvedPlaces == ["factory-shared-registry"])
    }

    @Test("A block's failure is sent at once, never queued in the buffer")
    func failureGoesPastTheBuffer() {
        let manager = InappShowFailureManagerMock()
        let content = EmbeddedBlockWebContent(inAppId: "block-failure-id",
                                              baseUrl: "https://inapp.local/stories",
                                              contentUrl: "https://inapp.local/stories.html",
                                              frequency: .unlimited,
                                              tags: ["campaign": "stories"],
                                              params: [:])

        EmbeddedBlockContentProviderFactory.report(failure: .webviewLoadFailed,
                                                   details: "the page did not load",
                                                   for: content,
                                                   to: manager)

        #expect(manager.addFailureCallCount == 0)
        #expect(manager.sendFailuresCallCount == 0)
        #expect(manager.sentAtOnce.count == 1)
        #expect(manager.sentAtOnce.first?.inappId == "block-failure-id")
        #expect(manager.sentAtOnce.first?.tags == ["campaign": "stories"])
    }

    @Test("A block's unanswered wait names the place, how long it waited and what the SDK was still missing",
          arguments: [(hasConfig: false, phase: EmbeddedBlockShowFailure.Phase.configMissing),
                      (hasConfig: true, phase: .resolvePending)])
    func unansweredWaitNamesThePlaceAndThePhase(hasConfig: Bool, phase: EmbeddedBlockShowFailure.Phase) {
        let manager = InappShowFailureManagerMock()
        let inappService = EmbeddedBlockInappServiceMock()
        inappService.hasConfig = hasConfig
        let registry = EmbeddedBlockPlaceRegistry(resolver: EmbeddedBlockResolverMock(resolution: .empty),
                                                  notificationCenter: NotificationCenter(),
                                                  fetchEmbeddedPlaces: { $0(nil) })
        let factory = EmbeddedBlockContentProviderFactory(registry: registry,
                                                          inappService: inappService,
                                                          failureManager: manager,
                                                          accounting: InappShowAccountingMock())

        SessionTemporaryStorage.shared.$ledger.mutate { $0.placesReportedUnanswered = [] }
        let place = "factory-silent-place"
        let provider = factory.makeProvider(placeSystemName: place)
        withExtendedLifetime(provider) {
            provider.reportAnswerTimedOut(waited: 30)
        }

        #expect(manager.waitBudgetExceeded.count == 1)
        #expect(manager.waitBudgetExceeded.first?.place == place)
        #expect(manager.waitBudgetExceeded.first?.waited == 30)
        #expect(manager.waitBudgetExceeded.first?.phase == phase)
        #expect(manager.sentAtOnce.isEmpty)
    }

    // MARK: - Helpers

    /// The resolver answers "empty": no page is created for such a block, so the factory's tests
    /// need no real web view.
    private func makeFactory() -> EmbeddedBlockContentProviderFactory {
        let registry = EmbeddedBlockPlaceRegistry(resolver: EmbeddedBlockResolverMock(resolution: .empty),
                                                  notificationCenter: NotificationCenter(),
                                                  fetchEmbeddedPlaces: { $0(nil) })
        return EmbeddedBlockContentProviderFactory(registry: registry,
                                                   inappService: EmbeddedBlockInappServiceMock(),
                                                   failureManager: InappShowFailureManagerMock(),
                                                   accounting: InappShowAccountingMock())
    }
}
