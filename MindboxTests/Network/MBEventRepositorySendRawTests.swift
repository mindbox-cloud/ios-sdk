//
//  MBEventRepositorySendRawTests.swift
//  MindboxTests
//

import Testing
import Foundation
@testable import Mindbox

@Suite("MBEventRepository")
struct MBEventRepositorySendRawTests {

    private static let trackingHost = "api-tracking.mindbox.ru"

    // MARK: - Test doubles

    private final class FakeNetworkFetcher: NetworkFetcher, @unchecked Sendable {
        var requestRawResult: Result<Data, MindboxError> = .success(Data())
        var requestTypedRawResponse: Result<Data, MindboxError> = .success(Data(#"{"status":"Success"}"#.utf8))
        var requestResult: Result<Void, MindboxError> = .success(())
        var holdsCompletion = false
        private(set) var heldCompletion: ((Result<Void, MindboxError>) -> Void)?
        private(set) var capturedRoute: Route?
        private(set) var requestRawCallCount = 0
        private(set) var requestTypedCallCount = 0

        func request<T>(
            type: T.Type,
            route: Route,
            needBaseResponse: Bool,
            completion: @escaping ((Result<T, MindboxError>) -> Void)
        ) where T: Decodable {
            requestTypedCallCount += 1
            capturedRoute = route
            let deliver: (Result<Data, MindboxError>) -> Void = { result in
                completion(result.map { try! JSONDecoder().decode(T.self, from: $0) })
            }
            if holdsCompletion {
                heldCompletion = { result in deliver(result.map { Data(#"{"status":"Success"}"#.utf8) }) }
            } else {
                deliver(requestTypedRawResponse)
            }
        }

        func request(route: Route, completion: @escaping ((Result<Void, MindboxError>) -> Void)) {
            capturedRoute = route
            completion(requestResult)
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

    private func makeRepository(fetcher: NetworkFetcher,
                                storage: MockPersistenceStorage,
                                trackingIdsResolver: TrackingIdsResolver = TrackingIdsResolver(),
                                declaredDomains: Set<String> = [Self.trackingHost]) -> MBEventRepository {
        MBEventRepository(fetcher: fetcher,
                          persistenceStorage: storage,
                          trackingIdsResolver: trackingIdsResolver,
                          trackingHostResolver: TrackingHostResolver(persistenceStorage: storage,
                                                                     declaredTrackingDomains: declaredDomains))
    }

    private func makeSyncEvent(operation: String = "TestOp", body: String = "{}") -> Event {
        let customEvent = CustomEvent(name: operation, payload: body)
        return Event(type: .syncEvent, body: BodyEncoder(encodable: customEvent).body)
    }

    private func awaitResult<T>(_ work: (@escaping (Result<T, MindboxError>) -> Void) -> Void) async -> Result<T, MindboxError> {
        await withCheckedContinuation { cont in
            work { result in
                cont.resume(returning: result)
            }
        }
    }

    private func makeTrackingIdsResolver(_ identifier: UUID?) -> TrackingIdsResolver {
        let trackingIdsResolver = TrackingIdsResolver()
        trackingIdsResolver.update(identifier: identifier)
        return trackingIdsResolver
    }

    private static func wrapper(of route: Route?) -> EventWrapper? {
        guard case let .asyncEvent(wrapper)? = route as? EventRoute else { return nil }
        return wrapper
    }

    // MARK: - Success: forwards raw bytes from fetcher

    @Test("Success path forwards raw bytes from fetcher.requestRaw")
    func sendRaw_success_forwardsRawBytes() async throws {
        let fetcher = FakeNetworkFetcher()
        let rawBody = #"{"status":"ValidationError","validationMessages":[{"message":"x","location":"/y"}]}"#.data(using: .utf8)!
        fetcher.requestRawResult = .success(rawBody)

        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage())

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
        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage())

        _ = await awaitResult { completion in
            repo.sendRaw(event: makeSyncEvent(), completion: completion)
        }

        let route = try #require(fetcher.capturedRoute as? EventRoute)
        if case .syncEvent = route {
        } else {
            Issue.record("Expected EventRoute.syncEvent, got \(route)")
        }
    }

    // MARK: - Failure: fetcher error is passed through

    @Test("Fetcher failure is propagated")
    func sendRaw_fetcherFailure_isPropagated() async throws {
        let fetcher = FakeNetworkFetcher()
        fetcher.requestRawResult = .failure(.connectionError)

        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage())

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

        let repo = makeRepository(fetcher: fetcher, storage: storage)

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

        let repo = makeRepository(fetcher: fetcher, storage: storage)

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

        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage())

        let isMain: Bool = await withCheckedContinuation { cont in
            repo.sendRaw(event: makeSyncEvent()) { _ in
                cont.resume(returning: Thread.isMainThread)
            }
        }

        #expect(isMain)
    }

    // MARK: - send<T>: completion always on the main queue (public contract)

    @Test("send<T> network-path completion is delivered on the main queue")
    func sendTyped_completion_onMainQueue() async throws {
        let fetcher = FakeNetworkFetcher()
        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage())

        let outcome: (isMain: Bool, isSuccess: Bool) = await withCheckedContinuation { cont in
            repo.send(type: OperationResponse.self, event: makeSyncEvent()) { result in
                if case .success = result {
                    cont.resume(returning: (Thread.isMainThread, true))
                } else {
                    cont.resume(returning: (Thread.isMainThread, false))
                }
            }
        }

        #expect(outcome.isMain)
        #expect(outcome.isSuccess)
        #expect(fetcher.requestTypedCallCount == 1)
    }

    @Test("send<T> early error (missing configuration) is delivered on the main queue")
    func sendTyped_missingConfiguration_errorOnMainQueue() async throws {
        let fetcher = FakeNetworkFetcher()
        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage(configured: false))

        let outcome: (isMain: Bool, errorKey: String?) = await withCheckedContinuation { cont in
            repo.send(type: OperationResponse.self, event: makeSyncEvent()) { result in
                guard case .failure(.internalError(let ie)) = result else {
                    cont.resume(returning: (Thread.isMainThread, nil))
                    return
                }
                cont.resume(returning: (Thread.isMainThread, ie.errorKey))
            }
        }

        #expect(outcome.isMain)
        #expect(outcome.errorKey == ErrorKey.invalidConfiguration.rawValue)
        #expect(fetcher.requestTypedCallCount == 0, "Fetcher must not be called when configuration is missing")
    }

    @Test("send<T> early error (missing deviceUUID) is delivered on the main queue")
    func sendTyped_missingDeviceUUID_errorOnMainQueue() async throws {
        let fetcher = FakeNetworkFetcher()
        let repo = makeRepository(fetcher: fetcher, storage: try makeStorage(deviceUUID: nil))

        let outcome: (isMain: Bool, errorKey: String?) = await withCheckedContinuation { cont in
            repo.send(type: OperationResponse.self, event: makeSyncEvent()) { result in
                guard case .failure(.internalError(let ie)) = result else {
                    cont.resume(returning: (Thread.isMainThread, nil))
                    return
                }
                cont.resume(returning: (Thread.isMainThread, ie.errorKey))
            }
        }

        #expect(outcome.isMain)
        #expect(outcome.errorKey == ErrorKey.invalidConfiguration.rawValue)
        #expect(fetcher.requestTypedCallCount == 0, "Fetcher must not be called when deviceUUID is missing")
    }

    // MARK: - Tracking ids

    @Test("A tracking ids event binds the granted id at send and stores its hash on success", .tags(.trackingIds))
    func send_trackingIdsEvent_bindsIdsAndStoresHash() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage()
        let trackingIdsResolver = makeTrackingIdsResolver(UUID())
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: trackingIdsResolver)
        let event = Event(type: .trackingIdsUpdated, body: "{}")
        trackingIdsResolver.expectFirstSend(of: event)

        let result = await awaitResult { completion in
            repo.send(event: event, completion: completion)
        }

        let route = try #require(fetcher.capturedRoute as? EventRoute)
        let attachment = try #require(Self.wrapper(of: route)?.trackingIds)
        #expect(attachment.carriesTrackingIds)
        #expect(route.baseURLKind == .tracking(Self.trackingHost))
        #expect(TrackingIdsRecord.reference(in: storage) == .hash(attachment.hash))
        #expect(fetcher.requestTypedCallCount == 1)
        #expect(throws: Never.self) { try result.get() }
    }

    @Test("An ids send without a confirmed Success answer stores no hash", .tags(.trackingIds))
    func send_withoutConfirmedSuccess_storesNoHash() async throws {
        let fetcher = FakeNetworkFetcher()
        fetcher.requestTypedRawResponse = .failure(.internalError(.init(errorKey: .parsing, rawError: nil)))
        let storage = try makeStorage()
        let trackingIdsResolver = makeTrackingIdsResolver(UUID())
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: trackingIdsResolver)
        let event = Event(type: .trackingIdsUpdated, body: "{}")
        trackingIdsResolver.expectFirstSend(of: event)

        _ = await awaitResult { completion in
            repo.send(event: event, completion: completion)
        }

        #expect(Self.wrapper(of: fetcher.capturedRoute)?.trackingIds?.carriesTrackingIds == true)
        #expect(TrackingIdsRecord.reference(in: storage) == nil)
    }

    @Test("A success that lands after a re-installation leaves the new installation unconfirmed", .tags(.trackingIds))
    func send_successAfterReinstallation_leavesTheNewInstallationUnconfirmed() throws {
        let fetcher = FakeNetworkFetcher()
        fetcher.holdsCompletion = true
        let storage = try makeStorage()
        storage.applicationInstanceId = "previous-installation"
        let trackingIdsResolver = makeTrackingIdsResolver(UUID())
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: trackingIdsResolver)
        let event = Event(type: .trackingIdsUpdated, body: "{}")
        trackingIdsResolver.expectFirstSend(of: event)

        repo.send(event: event) { _ in }
        let completion = try #require(fetcher.heldCompletion)
        storage.eraseMetadata()
        storage.applicationInstanceId = "new-installation"
        storage.trackingIdsRecord = TrackingIdsRecord(instanceId: "new-installation", reference: .unconfirmed).rawValue

        completion(.success(()))

        #expect(TrackingIdsRecord.reference(in: storage) == .unconfirmed)
    }

    @Test("An older success that lands after a newer claim leaves the record unconfirmed", .tags(.trackingIds))
    func send_olderSuccessAfterANewerClaim_leavesTheRecordUnconfirmed() throws {
        let fetcher = FakeNetworkFetcher()
        fetcher.holdsCompletion = true
        let storage = try makeStorage()
        storage.installationDate = Date()
        storage.applicationInstanceId = "installation"
        storage.trackingIdsRecord = TrackingIdsRecord(instanceId: "installation", reference: .unconfirmed).rawValue
        let trackingIdsResolver = TrackingIdsResolver()
        let changeDetector = TrackingIdsChangeDetector(trackingIdsResolver: trackingIdsResolver,
                                                       trackingHostResolver: TrackingHostResolver(persistenceStorage: storage,
                                                                                                  declaredTrackingDomains: [Self.trackingHost]),
                                                       persistenceStorage: storage)
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: trackingIdsResolver)

        trackingIdsResolver.update(identifier: nil)
        try #require(changeDetector.claimPendingChange())
        let revoke = Event(type: .trackingIdsUpdated, body: "{}")
        trackingIdsResolver.expectFirstSend(of: revoke)
        repo.send(event: revoke) { _ in }
        let revokeAnswer = try #require(fetcher.heldCompletion)

        trackingIdsResolver.update(identifier: UUID())
        try #require(changeDetector.claimPendingChange())
        revokeAnswer(.success(()))

        #expect(TrackingIdsRecord.reference(in: storage) == .unconfirmed)
    }

    @Test("An ids event first sent without ids stores no hash when sent again with them", .tags(.trackingIds))
    func send_idsEventFirstSentWithoutIds_storesNoHashOnResend() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage()
        let trackingIdsResolver = TrackingIdsResolver()
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: trackingIdsResolver)
        let event = Event(type: .trackingIdsUpdated, body: "{}")
        trackingIdsResolver.expectFirstSend(of: event)

        _ = await awaitResult { completion in
            repo.send(event: event, completion: completion)
        }
        trackingIdsResolver.update(identifier: UUID())
        _ = await awaitResult { completion in
            repo.send(event: event, completion: completion)
        }

        #expect(fetcher.requestTypedCallCount == 1)
        #expect(TrackingIdsRecord.reference(in: storage) == nil)
    }

    @Test("An ids event this launch did not create stores no hash", .tags(.trackingIds))
    func send_idsEventFromAnEarlierLaunch_storesNoHash() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage()
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: makeTrackingIdsResolver(UUID()))

        _ = await awaitResult { completion in
            repo.send(event: Event(type: .trackingIdsUpdated, body: "{}"), completion: completion)
        }

        #expect(fetcher.requestTypedCallCount == 1)
        #expect(TrackingIdsRecord.reference(in: storage) == nil)
    }

    @Test("Keepalive carries the current ids, Installed and InfoUpdated carry none", .tags(.trackingIds))
    func send_onlyIdsBearingTypesCarryIds() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage()
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: makeTrackingIdsResolver(UUID()))

        _ = await awaitResult { completion in
            repo.send(event: Event(type: .keepAlive, body: "{}"), completion: completion)
        }
        #expect(Self.wrapper(of: fetcher.capturedRoute)?.trackingIds?.carriesTrackingIds == true)

        for type in [Event.Operation.installed, .infoUpdated] {
            _ = await awaitResult { completion in
                repo.send(event: Event(type: type, body: "{}"), completion: completion)
            }
            let wrapper = try #require(Self.wrapper(of: fetcher.capturedRoute))
            #expect(wrapper.trackingIds == nil)
            #expect((fetcher.capturedRoute as? EventRoute)?.baseURLKind == .operations)
        }
    }

    @Test("No tracking host at send: operations host, body without ids, hash untouched", .tags(.trackingIds))
    func send_withoutTrackingHost_sendsWithoutIds() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage()
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: makeTrackingIdsResolver(UUID()), declaredDomains: [])

        _ = await awaitResult { completion in
            repo.send(event: Event(type: .trackingIdsUpdated, body: #"{"token":"t"}"#), completion: completion)
        }

        let route = try #require(fetcher.capturedRoute as? EventRoute)
        #expect(Self.wrapper(of: route)?.trackingIds == nil)
        #expect(route.baseURLKind == .operations)
        #expect(route.body == Data(#"{"token":"t"}"#.utf8))
        #expect(TrackingIdsRecord.reference(in: storage) == nil)
    }

    @Test("Revoked state sends an empty list on the operations host and stores the empty-list hash", .tags(.trackingIds))
    func send_revoked_sendsEmptyListAndStoresItsHash() async throws {
        let fetcher = FakeNetworkFetcher()
        let storage = try makeStorage()
        let trackingIdsResolver = makeTrackingIdsResolver(nil)
        let repo = makeRepository(fetcher: fetcher, storage: storage, trackingIdsResolver: trackingIdsResolver)
        let event = Event(type: .trackingIdsUpdated, body: "{}")
        trackingIdsResolver.expectFirstSend(of: event)

        _ = await awaitResult { completion in
            repo.send(event: event, completion: completion)
        }

        let route = try #require(fetcher.capturedRoute as? EventRoute)
        #expect(Self.wrapper(of: route)?.trackingIds?.ids == [])
        #expect(route.baseURLKind == .operations)
        #expect(TrackingIdsRecord.reference(in: storage) == .hash("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
    }

    @Test("eraseMetadata hands the accepted hash to the next installation as unconfirmed", .tags(.trackingIds))
    func eraseMetadata_handsTheAcceptedHashOverUnconfirmed() throws {
        let storage = try makeStorage()
        storage.trackingIdsRecord = TrackingIdsRecord(instanceId: storage.applicationInstanceId, reference: .hash("accepted")).rawValue

        storage.eraseMetadata()
        storage.applicationInstanceId = "next-installation"

        #expect(TrackingIdsRecord.reference(in: storage) == .unconfirmed)
    }

    @Test("The accepted hash belongs to the installation that sent it, any other one reads it as unconfirmed", .tags(.trackingIds))
    func acceptedHash_belongsToTheSendingInstallation() throws {
        let storage = try makeStorage()
        storage.applicationInstanceId = "installation"
        storage.trackingIdsRecord = TrackingIdsRecord(instanceId: "installation", reference: .hash("accepted")).rawValue
        #expect(TrackingIdsRecord.reference(in: storage) == .hash("accepted"))

        storage.applicationInstanceId = "another-installation"
        #expect(TrackingIdsRecord.reference(in: storage) == .unconfirmed)

        storage.applicationInstanceId = nil
        #expect(TrackingIdsRecord.reference(in: storage) == .unconfirmed)
    }
}
