//
//  EmbeddedBlockContentProviderFactoryTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

/// The factory keeps one promise: the provider is its own for every block, while the place registry is
/// shared. The independence of blocks sharing an id rests on this, so it is checked on its own.
@Suite("Embedded block content provider factory", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockContentProviderFactoryTests {

    /// Two blocks sharing an id are a legitimate case, and each must get its own provider: a
    /// shared one would make their state and page one for both.
    @Test("Every call makes its own provider")
    func eachCallMakesItsOwnProvider() {
        let place = "factory-independent-blocks"
        let factory = makeFactory()

        let first = factory.makeProvider(placeSystemName: place)
        let second = factory.makeProvider(placeSystemName: place)

        #expect(first !== second)
        withExtendedLifetime((first, second)) {}
    }

    /// The registry is shared exactly so that several blocks of one place live off a single resolve.
    /// This checks that the factory really hands the provider that registry instead of making its own,
    /// and that the provider it made pulls the place it was asked for.
    @Test("The provider pulls the requested place through the shared registry")
    func providerPullsThroughTheSharedRegistry() {
        let resolver = EmbeddedBlockResolverMock(resolution: .empty)
        let registry = EmbeddedBlockPlaceRegistry(resolver: resolver,
                                                  notificationCenter: NotificationCenter(),
                                                  fetchEmbeddedPlaces: { $0(nil) })
        let factory = EmbeddedBlockContentProviderFactory(registry: registry, feed: EmbeddedBlockFeedServiceMock())

        let provider = factory.makeProvider(placeSystemName: "factory-shared-registry")
        withExtendedLifetime(provider) {
            provider.start()
        }

        #expect(resolver.resolvedPlaces == ["factory-shared-registry"])
    }

    // MARK: - Helpers

    /// The resolver answers "empty": no page is created for such a block, so the factory's tests
    /// need no real web view.
    private func makeFactory() -> EmbeddedBlockContentProviderFactory {
        let registry = EmbeddedBlockPlaceRegistry(resolver: EmbeddedBlockResolverMock(resolution: .empty),
                                                  notificationCenter: NotificationCenter(),
                                                  fetchEmbeddedPlaces: { $0(nil) })
        return EmbeddedBlockContentProviderFactory(registry: registry,
                                                   feed: EmbeddedBlockFeedServiceMock())
    }
}
