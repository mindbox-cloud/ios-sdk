//
//  ConfigCandidatesTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 18.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

private enum CandidatesConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case config = "EmbeddedBlockConfig"
}

@Suite("Candidates of one config", .tags(.embeddedBlocks))
struct ConfigCandidatesTests {

    private enum Constants {
        static let place = "stories-list-container"
        static let blockId = "11111111-1111-1111-1111-111111111111"
        static let storyId = "22222222-2222-2222-2222-222222222222"
        static let modalId = "33333333-3333-3333-3333-333333333333"
    }

    private final class CountingVariantsFilter: VariantFilterProtocol {

        private let wrapped: VariantFilterProtocol
        private(set) var rebuilds = 0

        init(wrapped: VariantFilterProtocol) {
            self.wrapped = wrapped
        }

        func filter(_ variants: [MindboxFormVariantDTO]?) throws -> [MindboxFormVariant] {
            rebuilds += 1
            return try wrapped.filter(variants)
        }
    }

    private let config: ConfigResponse
    private let variantsFilter: CountingVariantsFilter
    private let sut: InappsFilterService

    init() throws {
        TestConfiguration.configure()
        SessionTemporaryStorage.shared.erase()

        config = try CandidatesConfig.config.getConfig()

        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [:]
        persistenceStorage.deviceUUID = "00000000-0000-0000-0000-000000000000"

        variantsFilter = CountingVariantsFilter(wrapped: DI.injectOrFail(VariantFilterProtocol.self))
        sut = InappsFilterService(persistenceStorage: persistenceStorage,
                                  variantsFilter: variantsFilter,
                                  sdkVersionValidator: DI.injectOrFail(SDKVersionValidator.self))
    }

    private func ids(_ inapps: [InApp]) -> Set<String> { Set(inapps.map { $0.id }) }

    @Test("Preparing a config rebuilds every in-app form exactly once")
    func rebuildsEveryFormOnce() throws {
        let inappCount = try #require(config.inapps?.elements.count)

        _ = sut.candidates(from: config)

        #expect(variantsFilter.rebuilds == inappCount)
    }

    @Test("No path rebuilds a form the prepared config already holds")
    func pathsReuseThePreparedForms() throws {
        let candidates = sut.candidates(from: config)
        let afterPreparing = variantsFilter.rebuilds

        _ = sut.filterForTrigger(in: candidates)
        _ = sut.filter(place: Constants.place, in: candidates)
        _ = sut.filter(feedIds: [Constants.storyId], in: candidates)
        _ = sut.filter(id: Constants.blockId, in: candidates)
        _ = sut.filterForTrigger(in: candidates)

        #expect(variantsFilter.rebuilds == afterPreparing)
    }

    @Test("The paths that share the candidates still disagree about direct call")
    func directCallIsCutPerPathAndNotInTheCandidates() throws {
        let candidates = sut.candidates(from: config)

        #expect(ids(candidates.renderable).contains(Constants.storyId))
        #expect(!ids(sut.filterForTrigger(in: candidates)).contains(Constants.storyId))
        #expect(ids(sut.filterForTrigger(in: candidates)).contains(Constants.modalId))
        #expect(ids(sut.filter(feedIds: [Constants.storyId], in: candidates)) == [Constants.storyId])
    }

    @Test("A place asks the candidates, not the config")
    func placeNarrowsThePreparedCandidates() throws {
        let candidates = sut.candidates(from: config)

        #expect(ids(sut.filter(place: Constants.place, in: candidates)).contains(Constants.blockId))
        #expect(sut.filter(place: "no-such-place", in: candidates).isEmpty)
    }
}
