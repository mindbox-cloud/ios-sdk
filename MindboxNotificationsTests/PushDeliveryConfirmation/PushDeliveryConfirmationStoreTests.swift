//
//  PushDeliveryConfirmationStoreTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@_spi(Internal) @testable import MindboxNotifications

@Suite("Push delivery confirmation: files for the app", .tags(.notifications, .deliveryConfirmation))
struct PushDeliveryConfirmationStoreTests {

    private let store = PushDeliveryConfirmationStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    )

    private func confirmation(_ path: String, receivedAt seconds: TimeInterval) -> PushDeliveryConfirmation {
        PushDeliveryConfirmation(
            url: URL(string: "https://confirm.mindbox.ru/\(path)")!,
            receivedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test("A saved confirmation waits until it is removed")
    func savesAndRemoves() throws {
        let first = confirmation("a", receivedAt: 100)
        try store.save(first)
        #expect(store.pending() == [first])

        store.remove(first)
        #expect(store.pending().isEmpty)
    }

    @Test("Saving one push twice leaves one file")
    func savesOncePerPush() throws {
        let first = confirmation("a", receivedAt: 100)
        try store.save(first)
        try store.save(first)
        #expect(store.pending().count == 1)
    }

    @Test("Waiting confirmations come oldest first")
    func pendingOldestFirst() throws {
        let newer = confirmation("b", receivedAt: 200)
        let older = confirmation("a", receivedAt: 100)
        try store.save(newer)
        try store.save(older)
        #expect(store.pending() == [older, newer])
    }

    @Test("Without a directory nothing is waiting")
    func emptyWithoutDirectory() {
        #expect(store.pending().isEmpty)
    }

    @Test("A broken file is removed, a foreign file is left alone")
    func dropsBrokenFiles() throws {
        let kept = confirmation("a", receivedAt: 100)
        try store.save(kept)
        let broken = store.directory.appendingPathComponent("broken.json")
        let foreign = store.directory.appendingPathComponent("notes.txt")
        try Data("{".utf8).write(to: broken)
        try Data("x".utf8).write(to: foreign)

        #expect(store.pending() == [kept])
        #expect(!FileManager.default.fileExists(atPath: broken.path))
        #expect(FileManager.default.fileExists(atPath: foreign.path))
    }

    @Test("No App Group means no store")
    func noStoreWithoutAppGroup() {
        #expect(PushDeliveryConfirmationStore(appGroupIdentifier: "") == nil)
    }
}
