//
//  EmbeddedBlockContentProviderFactoryTests.swift
//  MindboxTests
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

/// The factory keeps one promise: the provider is its own for every block, while the resolver and
/// the action handler are shared. The independence of blocks sharing an id rests on this, so it is
/// checked on its own.
///
/// The live-block counter is shared across the process, so each test uses its own id: otherwise
/// tests running in parallel would count each other's blocks.
@Suite("Embedded block content provider factory", .tags(.embeddedBlocks))
@MainActor
struct EmbeddedBlockContentProviderFactoryTests {

    /// Two blocks sharing an id are a legitimate case, and each must get its own provider: a
    /// shared one would make their state and page one for both.
    @Test("Every call makes its own provider")
    func eachCallMakesItsOwnProvider() {
        let id = "factory-independent-blocks"
        let factory = makeFactory()

        let first = factory.makeProvider(id: id)
        let second = factory.makeProvider(id: id)

        #expect(first !== second)
        withExtendedLifetime((first, second)) {
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 2)
        }
    }

    @Test("The provider is made for the requested id")
    func providerIsMadeForTheRequestedId() {
        let id = "factory-carries-the-id"
        let other = "factory-some-other-id"
        let factory = makeFactory()

        let provider = factory.makeProvider(id: id)

        withExtendedLifetime(provider) {
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: id) == 1)
            #expect(EmbeddedBlockWebViewProvider.liveCount(for: other) == 0)
        }
    }

    /// The resolver is shared exactly so that several blocks with the same id are resolved by one
    /// data fetch. This checks that the factory really hands the provider that resolver instead
    /// of making its own.
    @Test("The provider asks the shared resolver for its own id")
    func providerAsksTheSharedResolver() {
        let resolver = EmbeddedBlockResolverMock(resolution: .empty)
        let factory = EmbeddedBlockContentProviderFactory(resolver: resolver,
                                                          actionHandler: EmbeddedBlockActionHandlerMock())

        let provider = factory.makeProvider(id: "factory-shared-resolver")
        withExtendedLifetime(provider) {
            provider.start()
        }

        #expect(resolver.resolvedIds == ["factory-shared-resolver"])
    }

    // MARK: - Helpers

    /// The resolver answers "empty": no page is created for such a block, so the factory's tests
    /// need no real web view.
    private func makeFactory() -> EmbeddedBlockContentProviderFactory {
        EmbeddedBlockContentProviderFactory(resolver: EmbeddedBlockResolverMock(resolution: .empty),
                                            actionHandler: EmbeddedBlockActionHandlerMock())
    }
}
