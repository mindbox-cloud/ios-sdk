//
//  MBEventRepositorySendRawTests.swift
//  MindboxTests
//

import Testing
import Foundation
@testable import Mindbox

@Suite("MBEventRepository.sendRaw")
struct MBEventRepositorySendRawTests {

    // MARK: - Test doubles

    private final class FakeNetworkFetcher: NetworkFetcher, @unchecked Sendable {
        var requestRawResult: Result<Data, MindboxError> = .success(Data())
        private(set) var capturedRoute: Route?
        private(set) var requestRawCallCount = 0

        func request<T>(
            type: T.Type,
            route: Route,
            needBaseResponse: Bool,
            completion: @escaping ((Result<T, MindboxError>) -> Void)
        ) where T: Decodable {
            // not used by sendRaw
        }

        func request(route: Route, completion: @escaping ((Result<Void, MindboxError>) -> Void)) {
            // not used by sendRaw
        }

        func requestRaw(route: Route, completion: @escaping ((Result<Data, MindboxError>) -> Void)) {
            requestRawCallCount += 1
            capturedRoute = route
            completion(requestRawResult)
        }

        func cancelAllTasks() {}
    }

    private func makeStorage(configured: Bool = true, deviceUUID: String? = "test-uuid") throws -> MockPersistenceStorage {
        let storage = MockPersistenceStorage()
        if configured {
            storage.configuration = try MBConfiguration(endpoint: "test-endpoint", domain: "api.mindbox.ru")
        }
        storage.deviceUUID = deviceUUID
        return storage
    }

    private func makeSyncEvent(operation: String = "TestOp", body: String = "{}") -> Event {
        let customEvent = CustomEvent(name: operation, payload: body)
        return Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
    }

    private func awaitResult(_ work: (@escaping (Result<Data, MindboxError>) -> Void) -> Void) async -> Result<Data, MindboxError> {
        await withCheckedContinuation { cont in
            work { result in
                cont.resume(returning: result)
            }
        }
    }

    // MARK: - Success: forwards raw bytes from fetcher

    @Test("Success path forwards raw bytes from fetcher.requestRaw")
    func sendRaw_success_forwardsRawBytes() async throws {
        let fetcher = FakeNetworkFetcher()
        let rawBody = #"{"status":"ValidationError","validationMessages":[{"message":"x","location":"/y"}]}"#.data(using: .utf8)!
        fetcher.requestRawResult = .success(rawBody)

        let repo = MBEventRepository(
            fetcher: fetcher,
            persistenceStorage: try makeStorage()
        )

        let result = await awaitResult { completion in
            repo.sendRaw(event: makeSyncEvent(), completion: completion)
        }

        switch result {
        case .success(let data):
            #expect(data == rawBody)
        case .failure(let error):
            Issue.record("Expected success, got \(error)")
        }
        #expect(fetcher.requestRawCallCount == 1)
    }

    // MARK: - Route: syncEvent uses EventRoute.syncEvent

    @Test("syncEvent event yields EventRoute.syncEvent")
    func sendRaw_syncEvent_routesToSyncEndpoint() async throws {
        let fetcher = FakeNetworkFetcher()
        let repo = MBEventRepository(
            fetcher: fetcher,
            persistenceStorage: try makeStorage()
        )

        _ = await awaitResult { completion in
            repo.sendRaw(event: makeSyncEvent(), completion: completion)
        }

        let route = try #require(fetcher.capturedRoute as? EventRoute)
        if case .syncEvent = route {
            // expected
        } else {
            Issue.record("Expected EventRoute.syncEvent, got \(route)")
        }
    }

    // MARK: - Failure: fetcher error is passed through

    @Test("Fetcher failure is propagated")
    func sendRaw_fetcherFailure_isPropagated() async throws {
        let fetcher = FakeNetworkFetcher()
        fetcher.requestRawResult = .failure(.connectionError)

        let repo = MBEventRepository(
            fetcher: fetcher,
            persistenceStorage: try makeStorage()
        )

        let result = await awaitResult { completion in
            repo.sendRaw(event: makeSyncEvent(), completion: completion)
        }

        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            guard case .connectionError = error else {
                Issue.record("Expected .connectionError, got \(error)")
                return
            }
        }
    }

    // MARK: - Missing configuration → invalidConfiguration error

    @Test("Missing configuration returns invalidConfiguration error")
    func sendRaw_missingConfiguration_returnsInvalidConfiguration() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage(configured: false)

        let repo = MBEventRepository(fetcher: fetcher, persistenceStorage: storage)

        let result = await awaitResult { completion in
            repo.sendRaw(event: makeSyncEvent(), completion: completion)
        }

        switch result {
        case .success:
            Issue.record("Expected failure when configuration is nil")
        case .failure(let error):
            guard case .internalError(let ie) = error else {
                Issue.record("Expected .internalError, got \(error)")
                return
            }
            #expect(ie.errorKey == ErrorKey.invalidConfiguration.rawValue)
        }
        #expect(fetcher.requestRawCallCount == 0, "Fetcher must not be called when configuration is missing")
    }

    // MARK: - Missing deviceUUID → invalidConfiguration error

    @Test("Missing deviceUUID returns invalidConfiguration error")
    func sendRaw_missingDeviceUUID_returnsInvalidConfiguration() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage(deviceUUID: nil)

        let repo = MBEventRepository(fetcher: fetcher, persistenceStorage: storage)

        let result = await awaitResult { completion in
            repo.sendRaw(event: makeSyncEvent(), completion: completion)
        }

        switch result {
        case .success:
            Issue.record("Expected failure when deviceUUID is nil")
        case .failure(let error):
            guard case .internalError(let ie) = error else {
                Issue.record("Expected .internalError, got \(error)")
                return
            }
            #expect(ie.errorKey == ErrorKey.invalidConfiguration.rawValue)
        }
        #expect(fetcher.requestRawCallCount == 0, "Fetcher must not be called when deviceUUID is missing")
    }

    // MARK: - Completion hops to main queue

    @Test("Completion is delivered on the main queue")
    func sendRaw_completion_onMainQueue() async throws {
        let fetcher = FakeNetworkFetcher()
        fetcher.requestRawResult = .success(Data("ok".utf8))

        let repo = MBEventRepository(
            fetcher: fetcher,
            persistenceStorage: try makeStorage()
        )

        let isMain: Bool = await withCheckedContinuation { cont in
            repo.sendRaw(event: makeSyncEvent()) { _ in
                cont.resume(returning: Thread.isMainThread)
            }
        }

        #expect(isMain)
    }
}
