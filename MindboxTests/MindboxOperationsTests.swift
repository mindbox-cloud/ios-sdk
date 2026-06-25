//
//  MindboxOperationsTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 11.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

/// Contract tests for the public operations pipeline (MOBILE-208): the heavy work
/// runs on the serial eventQueue, yet every externally observable guarantee holds —
/// call order equals DB write order, the body is snapshotted at call time, invalid
/// input is dropped before the hop, executeSyncOperation completions always arrive
/// on the main thread, and track() stays synchronous.
@Suite("Public operations contract", .serialized, .tags(.customOperation))
struct MindboxOperationsTests {

    private let persistenceStorage: PersistenceStorage
    private let databaseRepository: DatabaseRepositoryProtocol

    init() throws {
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.reset()
        databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try databaseRepository.erase()
        Mindbox.shared.assembly()
        // Keep GuaranteedDeliveryManager from consuming (deleting) the events these
        // tests assert on — an earlier test may have enabled scheduling.
        DI.injectOrFail(GuaranteedDeliveryManager.self).canScheduleOperations = false
    }

    // MARK: - Helpers

    /// Events are written asynchronously on eventQueue; poll the repository until
    /// `count` events named `name` have landed (see `pollUntil` for the timeout contract).
    private func waitForCustomEvents(named name: String, count: Int) async throws -> [CustomEvent] {
        try await pollUntil(value: { try fetchCustomEvents(named: name) },
                            condition: { $0.count >= count })
    }

    /// Custom events named `name`, in the repository's own send order
    /// (fetchRequestForSend sorts by retry/enqueue timestamp) — i.e. exactly the
    /// order GuaranteedDeliveryManager would deliver them in.
    private func fetchCustomEvents(named name: String) throws -> [CustomEvent] {
        try databaseRepository
            .query(fetchLimit: 200, retryDeadline: 60)
            .filter { $0.type == .customEvent }
            .compactMap { try? JSONDecoder().decode(CustomEvent.self, from: Data($0.body.utf8)) }
            .filter { $0.name == name }
    }

    /// Thread-safe one-shot value holder for asserting on completion callbacks.
    /// Polled with a deadline instead of awaiting a continuation, so a regression
    /// that never calls the completion FAILS the test instead of hanging it.
    private final class ResultBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: T?
        func set(_ value: T) { lock.lock(); stored = value; lock.unlock() }
        var value: T? { lock.lock(); defer { lock.unlock() }; return stored }
    }

    private func waitForValue<T>(in box: ResultBox<T>) async -> T? {
        await pollUntil(value: { box.value }, condition: { $0 != nil })
    }

    // MARK: - Ordering

    @Test("Burst of async operations is persisted in call order")
    func eventOrderMatchesCallOrder() async throws {
        struct Payload: Decodable { let i: Int }
        let total = 30
        for i in 0..<total {
            Mindbox.shared.executeAsyncOperation(operationSystemName: "Test.Order", json: "{\"i\":\(i)}")
        }
        let events = try await waitForCustomEvents(named: "Test.Order", count: total)
        let indices = events.compactMap { try? JSONDecoder().decode(Payload.self, from: Data($0.payload.utf8)).i }
        #expect(indices == Array(0..<total))
    }

    // MARK: - Body snapshot

    private final class MutableBody: OperationBodyRequestType {
        var value: String?
        enum CodingKeys: String, CodingKey { case value }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
        }
    }

    @Test("Operation body is snapshotted at call time; later host mutations don't leak")
    func bodySnapshotTakenOnCaller() async throws {
        let body = MutableBody()
        body.value = "original"
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test.Snapshot", operationBody: body)
        body.value = "mutated-right-after-return"

        let events = try await waitForCustomEvents(named: "Test.Snapshot", count: 1)
        let payload = try #require(events.first?.payload)
        #expect(payload.contains("original"))
        #expect(!payload.contains("mutated-right-after-return"))
    }

    // MARK: - Invalid input is dropped before the queue hop

    @Test("Invalid operation name is dropped; the pipeline keeps working")
    func invalidNameDropped() async throws {
        Mindbox.shared.executeAsyncOperation(operationSystemName: "плохое имя", json: "{}")
        Mindbox.shared.executeAsyncOperation(operationSystemName: "op\n", json: "{}")
        // Sentinel after the invalid calls: the serial queue preserves order, so once
        // it lands we know the invalid ones were dropped, not just delayed.
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test.AfterInvalidName", json: "{}")

        let sentinel = try await waitForCustomEvents(named: "Test.AfterInvalidName", count: 1)
        #expect(sentinel.count == 1)
        let all = try databaseRepository.query(fetchLimit: 200, retryDeadline: 60)
            .filter { $0.type == .customEvent }
        #expect(all.count == 1)
    }

    @Test("Invalid JSON is dropped; the pipeline keeps working")
    func invalidJSONDropped() async throws {
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test.BadJson", json: "not json at all")
        Mindbox.shared.executeAsyncOperation(operationSystemName: "Test.AfterInvalidJson", json: "{}")

        let sentinel = try await waitForCustomEvents(named: "Test.AfterInvalidJson", count: 1)
        #expect(sentinel.count == 1)
        #expect(try fetchCustomEvents(named: "Test.BadJson").isEmpty)
    }

    // MARK: - executeSyncOperation completion thread

    @Test("executeSyncOperation delivers its completion on the main thread")
    func syncCompletionArrivesOnMain() async throws {
        persistenceStorage.configuration = try MBConfiguration(endpoint: "test-endpoint", domain: "api.mindbox.ru")
        persistenceStorage.deviceUUID = "00000000-0000-0000-0000-000000000001"

        let box = ResultBox<Bool>()
        Mindbox.shared.executeSyncOperation(operationSystemName: "Test.Sync", json: "{}") { _ in
            box.set(Thread.isMainThread)
        }
        let deliveredOnMain = await waitForValue(in: box)
        #expect(deliveredOnMain == true, "completion not delivered (nil) or delivered off main (false)")
    }

    // MARK: - pushClicked

    @Test("pushClicked persists the click event for guaranteed delivery")
    func pushClickPersisted() async throws {
        Mindbox.shared.pushClicked(uniqueKey: "test-push-unique-key")

        let clicks = try await pollUntil(
            value: { try databaseRepository.query(fetchLimit: 200, retryDeadline: 60).filter { $0.type == .trackClick } },
            condition: { !$0.isEmpty })
        #expect(clicks.count == 1)
        #expect(clicks.first?.body.contains("test-push-unique-key") == true)
    }

    // MARK: - track() synchronicity

    // track(_:) must finish its work before returning: handlePush/handleUniversalLink
    // set skipNextDirectTrackVisit, which the didBecomeActive-driven trackDirect
    // consumes on controllerQueue. If track() is ever deferred to a queue "for
    // symmetry" with the operation methods, that flag write starts racing trackDirect
    // — this test trips then. lastTrackVisit is written in the same synchronous chain
    // as the (private) flag, so it stands in for it.
    @Test("track(.universalLink) applies its effects before returning (stays synchronous)")
    func trackAppliesEffectsSynchronously() {
        SessionTemporaryStorage.shared.erase()
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://test-site.s.mindbox.ru")

        Mindbox.shared.track(.universalLink(activity))

        // Asserted immediately, with no waiting: the effect must already be visible
        // the moment the call returns.
        #expect(SessionTemporaryStorage.shared.lastTrackVisit?.source == .link)
    }

    @Test("executeSyncOperation early errors (unconfigured SDK) are delivered on main too")
    func syncEarlyErrorArrivesOnMain() async {
        // configuration is nil after reset() in init — the "Configuration is not set" path.
        let box = ResultBox<(onMain: Bool, isFailure: Bool)>()
        Mindbox.shared.executeSyncOperation(operationSystemName: "Test.Sync", json: "{}") { result in
            if case .failure = result {
                box.set((Thread.isMainThread, true))
            } else {
                box.set((Thread.isMainThread, false))
            }
        }
        let result = await waitForValue(in: box)
        #expect(result?.onMain == true)
        #expect(result?.isFailure == true)
    }

    @Test("executeSyncOperation with invalid JSON delivers a .failure on the main thread")
    func syncInvalidJSONDeliversFailureOnMain() async throws {
        // Configure the SDK so the only path to a failure is the invalid-JSON branch, not
        // the "Configuration is not set" early error. This pins the regression where invalid
        // JSON dropped the operation without ever invoking `completion`, hanging the caller.
        persistenceStorage.configuration = try MBConfiguration(endpoint: "test-endpoint", domain: "api.mindbox.ru")
        persistenceStorage.deviceUUID = "00000000-0000-0000-0000-000000000001"

        let box = ResultBox<(onMain: Bool, isFailure: Bool)>()
        Mindbox.shared.executeSyncOperation(operationSystemName: "Test.Sync", json: "not json at all") { result in
            if case .failure = result {
                box.set((Thread.isMainThread, true))
            } else {
                box.set((Thread.isMainThread, false))
            }
        }
        let result = await waitForValue(in: box)
        #expect(result?.onMain == true, "completion not delivered (nil) or delivered off main")
        #expect(result?.isFailure == true, "invalid JSON must deliver a .failure, not a .success")
    }
}
