//
//  PushDeliveryConfirmationStoreTests.swift
//  MindboxNotificationsTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import MindboxNotifications

@Suite("Push delivery confirmation: the record on disk", .tags(.notifications, .pushDeliveryConfirmation))
struct PushDeliveryConfirmationStoreTests {

    private let address = "https://api.mindbox.ru/delivered?id=42"

    private var hash: String {
        SHA256.hash(data: Data(address.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func confirmation(
        address: String? = nil,
        receivedAt: Date = Date(timeIntervalSince1970: 1_800_000_000.5)
    ) throws -> PushDeliveryConfirmation {
        PushDeliveryConfirmation(url: try #require(URL(string: address ?? self.address)), receivedAt: receivedAt)
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    @Test("A new record is written as .pending and holds the URL, the receive time and the version")
    func savesPending() throws {
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmation = try confirmation()

        try store.save(confirmation)

        #expect(hash.count == 64)
        #expect(store.fileNames == ["\(hash).pending"])
        let json = try jsonObject(at: store.fileURL(for: confirmation, state: .pending))
        #expect(json.count == 3)
        #expect(json["version"] as? Int == 1)
        #expect(json["url"] as? String == address)
        #expect(json["receivedAt"] as? Int64 == 1_800_000_000_500)
        #expect(json["lastStatusCode"] == nil)
        #expect(json["lastAttemptAt"] == nil)
    }

    @Test("One URL is one record however many times it is saved")
    func oneUrlOneRecord() throws {
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmation = try confirmation()

        try store.save(confirmation)
        try store.save(confirmation)

        #expect(store.fileNames == ["\(hash).pending"])
        #expect(store.directory.lastPathComponent != "MindboxPushDeliveryConfirmations")
        #expect(PushDeliveryConfirmationStore.directoryName == "MindboxPushDeliveryConfirmations")
    }

    @Test("Releasing writes .json with the last answer and removes .pending")
    func releases() throws {
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmation = try confirmation()
        try store.save(confirmation)

        try store.release(confirmation, lastStatusCode: 429, lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_003))

        #expect(store.fileNames == ["\(hash).json"])
        let json = try jsonObject(at: store.fileURL(for: confirmation, state: .released))
        #expect(json.count == 5)
        #expect(json["version"] as? Int == 1)
        #expect(json["url"] as? String == address)
        #expect(json["receivedAt"] as? Int64 == 1_800_000_000_500)
        #expect(json["lastStatusCode"] as? Int == 429)
        #expect(json["lastAttemptAt"] as? Int64 == 1_800_000_003_000)
    }

    @Test("Releasing without an answer leaves the status code out")
    func releasesWithoutStatus() throws {
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmation = try confirmation()
        try store.save(confirmation)

        try store.release(confirmation, lastStatusCode: nil, lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_003))

        let json = try jsonObject(at: store.fileURL(for: confirmation, state: .released))
        #expect(json["lastStatusCode"] == nil)
        #expect(json["lastAttemptAt"] as? Int64 == 1_800_000_003_000)
    }

    @Test("Releasing a record that was never saved still writes .json")
    func releasesWithoutPending() throws {
        let store = PushDeliveryConfirmationStore.temporary()

        try store.release(try confirmation(), lastStatusCode: 500, lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_003))

        #expect(store.fileNames == ["\(hash).json"])
    }

    @Test("Removing deletes the record in both states")
    func removesBothStates() throws {
        let store = PushDeliveryConfirmationStore.temporary()
        let confirmation = try confirmation()
        try store.save(confirmation)
        try Data("{}".utf8).write(to: store.fileURL(for: confirmation, state: .released))
        #expect(store.fileNames.count == 2)

        store.remove(confirmation)

        #expect(store.fileNames.isEmpty)
    }

    @Test("Removing deletes only the record of that confirmation")
    func removesOneRecord() throws {
        let store = PushDeliveryConfirmationStore.temporary()
        let first = try confirmation(address: "https://one.mindbox.ru/delivered")
        let second = try confirmation(address: "https://two.mindbox.ru/delivered")
        try store.save(first)
        try store.save(second)

        store.remove(first)

        #expect(store.fileNames == [store.fileURL(for: second, state: .pending).lastPathComponent])
    }

    @Test("The success marker holds the time in milliseconds as text")
    func marksSuccess() throws {
        let store = PushDeliveryConfirmationStore.temporary()

        try store.markSuccess(at: Date(timeIntervalSince1970: 1_800_000_000.5))

        #expect(PushDeliveryConfirmationStore.successMarkerName == "last-success")
        let text = try String(contentsOf: store.directory.appendingPathComponent("last-success"), encoding: .utf8)
        #expect(text == "1800000000500")
    }

    @Test("A later success replaces the marker")
    func marksSuccessAgain() throws {
        let store = PushDeliveryConfirmationStore.temporary()

        try store.markSuccess(at: Date(timeIntervalSince1970: 1_800_000_000))
        try store.markSuccess(at: Date(timeIntervalSince1970: 1_800_000_060))

        let text = try String(contentsOf: store.directory.appendingPathComponent("last-success"), encoding: .utf8)
        #expect(text == "1800000060000")
        #expect(store.fileNames == ["last-success"])
    }

    @Test("The file extensions of the two states are fixed")
    func stateExtensions() {
        #expect(PushDeliveryConfirmationStore.pendingExtension == "pending")
        #expect(PushDeliveryConfirmationStore.releasedExtension == "json")
    }

    @Test("The signal name carries the host bundle identifier")
    func signalName() {
        #expect(PushDeliveryConfirmationSignal.name(hostBundleIdentifier: "cloud.mindbox.app")
                == "cloud.Mindbox.pushDeliveryConfirmation.cloud.mindbox.app")
    }
}
