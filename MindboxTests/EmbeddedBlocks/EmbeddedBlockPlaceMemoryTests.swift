//
//  EmbeddedBlockPlaceMemoryTests.swift
//  MindboxTests
//
//  Created by vailence on 24.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("Embedded block place memory", .tags(.embeddedBlocks))
struct EmbeddedBlockPlaceMemoryTests {

    private let storage = MockPersistenceStorage()

    private static let moment = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeMemory(now: Date = EmbeddedBlockPlaceMemoryTests.moment) -> EmbeddedBlockPlaceMemory {
        EmbeddedBlockPlaceMemory(persistenceStorage: storage, now: { now })
    }

    @Test("A place is not remembered until content was shown there")
    func unknownPlaceIsNotRemembered() {
        #expect(makeMemory().hasShownContent(at: "stories") == false)
    }

    @Test("Shown content is remembered with the moment it was written down")
    func shownContentIsRemembered() {
        let memory = makeMemory()

        memory.rememberShownContent(at: "stories")

        #expect(memory.hasShownContent(at: "stories"))
        #expect(memory.record(at: "stories") == EmbeddedBlockPlaceRecord(rememberedAt: Self.moment))
    }

    /// A shown block shows again on every return to the screen; only the first show is worth a write.
    @Test("A place is written once")
    func placeIsWrittenOnce() {
        let memory = makeMemory()
        memory.rememberShownContent(at: "stories")
        let writes = storage.embeddedBlockPlaceRecordsWriteCount

        memory.rememberShownContent(at: "stories")

        #expect(storage.embeddedBlockPlaceRecordsWriteCount == writes)
        #expect(memory.record(at: "stories") == EmbeddedBlockPlaceRecord(rememberedAt: Self.moment))
    }

    @Test("Forgetting a place removes its record and leaves the others")
    func forgettingRemovesOnlyThePlace() {
        let memory = makeMemory()
        memory.rememberShownContent(at: "stories")
        memory.rememberShownContent(at: "banner")

        memory.forgetPlace("stories")

        #expect(memory.hasShownContent(at: "stories") == false)
        #expect(memory.hasShownContent(at: "banner"))
    }

    @Test("Forgetting a place that was never remembered does not touch the storage")
    func forgettingAnUnknownPlaceWritesNothing() {
        let memory = makeMemory()
        let writes = storage.embeddedBlockPlaceRecordsWriteCount

        memory.forgetPlace("stories")

        #expect(storage.embeddedBlockPlaceRecordsWriteCount == writes)
    }

    @Test("A place remembered again after being forgotten is written anew")
    func placeRememberedAgainIsWrittenAnew() {
        let memory = makeMemory()
        memory.rememberShownContent(at: "stories")
        memory.forgetPlace("stories")

        memory.rememberShownContent(at: "stories")

        #expect(memory.hasShownContent(at: "stories"))
    }

    @Test("The memory lives in the storage, not in the instance: the next launch sees it")
    func memoryIsSharedThroughTheStorage() {
        makeMemory().rememberShownContent(at: "stories")

        #expect(makeMemory().hasShownContent(at: "stories"))
    }

    @Test("A record that cannot be decoded still counts as shown: the fact is its presence")
    func unreadableRecordStillCountsAsShown() {
        storage.embeddedBlockPlaceRecords = ["stories": Data("garbage".utf8)]

        let memory = makeMemory()

        #expect(memory.hasShownContent(at: "stories"))
        #expect(memory.record(at: "stories") == nil)
    }

    @Test("The record is JSON with an ISO 8601 date, so a later field can join it")
    func recordIsStoredAsJSON() throws {
        makeMemory(now: Date(timeIntervalSince1970: 0)).rememberShownContent(at: "stories")

        let data = try #require(storage.embeddedBlockPlaceRecords?["stories"])
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["rememberedAt"] as? String == "1970-01-01T00:00:00Z")
    }
}
