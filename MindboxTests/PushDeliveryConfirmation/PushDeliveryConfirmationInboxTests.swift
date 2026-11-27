//
//  PushDeliveryConfirmationInboxTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@_spi(Internal) @testable import Mindbox
#if SWIFT_PACKAGE
@_spi(Internal)
import MindboxShared
#endif

@Suite("Push delivery confirmation inbox")
struct PushDeliveryConfirmationInboxTests {
    private let directory: URL
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let validURL = "https://example.com/confirm?id=1"

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InboxTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    @discardableResult
    private func write(
        _ name: String,
        ext: String = PushDeliveryConfirmationRecord.releasedExtension,
        url: String? = nil,
        receivedAt: Int64
    ) throws -> URL {
        let record = PushDeliveryConfirmationRecord(url: url ?? validURL, receivedAt: receivedAt)
        let file = directory.appendingPathComponent(name).appendingPathExtension(ext)
        try JSONEncoder().encode(record).write(to: file)
        return file
    }

    @discardableResult
    private func writeRaw(_ name: String, _ content: String, ext: String = "json") throws -> URL {
        let file = directory.appendingPathComponent(name).appendingPathExtension(ext)
        try Data(content.utf8).write(to: file)
        return file
    }

    private func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path)
    }

    private var inbox: PushDeliveryConfirmationInbox {
        PushDeliveryConfirmationInbox(directory: directory)
    }

    @Test("A file that cannot be read is neither returned, nor deleted, nor counted")
    func unreadableFileIsSkipped() throws {
        let directoryNamedLikeRecord = directory.appendingPathComponent("a").appendingPathExtension("json")
        try FileManager.default.createDirectory(at: directoryNamedLikeRecord, withIntermediateDirectories: true)

        let result = inbox.items(now: now)

        #expect(result.items.isEmpty)
        #expect(result.dropped.isEmpty)
        #expect(exists(directoryNamedLikeRecord))
    }

    @Test("K5: records are returned in ascending receivedAt order")
    func ordersByReceivedAt() throws {
        try write("a", receivedAt: milliseconds(now) - 300)
        try write("b", receivedAt: milliseconds(now) - 100)
        try write("c", receivedAt: milliseconds(now) - 200)

        let result = inbox.items(now: now)

        let base = milliseconds(now)
        let expected: [Int64] = [base - 300, base - 200, base - 100]
        #expect(result.items.map { $0.record.receivedAt } == expected)
        #expect(result.dropped.isEmpty)
    }

    @Test("K26: a pending record of 39 seconds is not returned and stays on disk")
    func youngPendingStays() throws {
        let file = try write("a", ext: "pending", receivedAt: milliseconds(now) - 39_000)

        #expect(inbox.items(now: now).items.isEmpty)
        #expect(exists(file))
    }

    @Test("K43: a pending record of 40 seconds is returned")
    func abandonedPendingIsReturned() throws {
        let file = try write("a", ext: "pending", receivedAt: milliseconds(now) - 40_000)

        let result = inbox.items(now: now)

        #expect(result.items.map { $0.fileURL.lastPathComponent } == [file.lastPathComponent])
    }

    @Test("Garbage file is dropped as unreadable and removed")
    func garbageIsUnreadable() throws {
        let file = try writeRaw("a", "not json at all")

        let result = inbox.items(now: now)

        #expect(result.items.isEmpty)
        #expect(result.dropped[.unreadable] == 1)
        #expect(!exists(file))
    }

    @Test("K48: records with a non-https, empty or malformed url are dropped as unreadable")
    func badURLsAreUnreadable() throws {
        let files = [
            try write("a", url: "http://example.com/confirm", receivedAt: milliseconds(now)),
            try write("b", url: "", receivedAt: milliseconds(now)),
            try write("c", url: "not a url", receivedAt: milliseconds(now))
        ]

        let result = inbox.items(now: now)

        #expect(result.items.isEmpty)
        #expect(result.dropped[.unreadable] == 3)
        #expect(files.allSatisfy { !exists($0) })
    }

    @Test("K56: unknown fields are accepted, missing url or receivedAt makes the record unreadable")
    func unknownAndMissingFields() throws {
        let extra = try writeRaw(
            "a",
            "{\"version\":1,\"url\":\"\(validURL)\",\"receivedAt\":\(milliseconds(now)),\"extra\":\"x\",\"nested\":{\"a\":1}}"
        )
        let noURL = try writeRaw("b", "{\"version\":1,\"receivedAt\":\(milliseconds(now))}")
        let noReceivedAt = try writeRaw("c", "{\"version\":1,\"url\":\"\(validURL)\"}")

        let result = inbox.items(now: now)

        #expect(result.items.map { $0.fileURL.lastPathComponent } == [extra.lastPathComponent])
        #expect(result.dropped[.unreadable] == 2)
        #expect(!exists(noURL))
        #expect(!exists(noReceivedAt))
    }

    @Test("K28: a record older than 6 months is expired and removed, one a day younger is returned")
    func expiredRecords() throws {
        let boundary = try #require(Calendar.current.date(byAdding: .month, value: -6, to: now))
        let day: TimeInterval = 86_400
        let old = try write("old", receivedAt: milliseconds(boundary.addingTimeInterval(-day)))
        let fresh = try write("fresh", receivedAt: milliseconds(boundary.addingTimeInterval(day)))

        let result = inbox.items(now: now)

        #expect(result.items.map { $0.fileURL.lastPathComponent } == [fresh.lastPathComponent])
        #expect(result.dropped[.expired] == 1)
        #expect(!exists(old))
        #expect(exists(fresh))
    }

    @Test("Over the limit the oldest records are removed")
    func overLimit() throws {
        var files: [URL] = []
        for index in 1...5 {
            files.append(try write("r\(index)", receivedAt: milliseconds(now) - Int64(index) * 1000))
        }

        let result = PushDeliveryConfirmationInbox(directory: directory, maxRecords: 3).items(now: now)

        #expect(result.items.count == 3)
        let base = milliseconds(now)
        let expected: [Int64] = [base - 3000, base - 2000, base - 1000]
        #expect(result.items.map { $0.record.receivedAt } == expected)
        #expect(result.dropped[.overLimit] == 2)
        #expect(!exists(files[3]))
        #expect(!exists(files[4]))
        #expect(exists(files[0]))
    }

    @Test("hasRecords is false for an empty folder and for a folder with only last-success")
    func hasRecordsFalse() throws {
        #expect(!inbox.hasRecords)
        try writeRaw(PushDeliveryConfirmationRecord.successMarkerName, "1", ext: "")
        #expect(!inbox.hasRecords)
    }

    @Test("hasRecords is true for a json or a pending file")
    func hasRecordsTrue() throws {
        let released = try write("a", receivedAt: milliseconds(now))
        #expect(inbox.hasRecords)
        try FileManager.default.removeItem(at: released)
        try write("b", ext: "pending", receivedAt: milliseconds(now))
        #expect(inbox.hasRecords)
    }

    @Test("remove deletes only the given file")
    func removeOne() throws {
        let first = try write("a", receivedAt: milliseconds(now) - 2000)
        let second = try write("b", receivedAt: milliseconds(now) - 1000)

        let items = inbox.items(now: now).items
        inbox.remove(items[0])

        #expect(!exists(first))
        #expect(exists(second))
    }

    @Test("lastSuccess reads milliseconds, nil when absent or not a number")
    func lastSuccess() throws {
        #expect(inbox.lastSuccess() == nil)
        let marker = directory.appendingPathComponent(PushDeliveryConfirmationRecord.successMarkerName)
        try Data("1799999999123".utf8).write(to: marker)
        #expect(inbox.lastSuccess() == 1_799_999_999_123)
        try Data("abc".utf8).write(to: marker)
        #expect(inbox.lastSuccess() == nil)
    }

    @Test("K31: an empty app group identifier gives no inbox")
    func emptyAppGroup() {
        #expect(PushDeliveryConfirmationInbox(appGroupIdentifier: "") == nil)
    }
}
