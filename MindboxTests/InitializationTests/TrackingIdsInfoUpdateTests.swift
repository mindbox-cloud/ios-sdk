//
//  TrackingIdsInfoUpdateTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 03.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
import MindboxLogger
@testable import Mindbox

@Suite("Tracking ids InfoUpdated", .serialized, .tags(.trackingIds))
@MainActor
struct TrackingIdsInfoUpdateTests {

    private let storage: PersistenceStorage
    private let coreController: CoreController
    private let controllerQueue: DispatchQueue
    private let databaseRepository: DatabaseRepositoryProtocol
    private let zeros = UUID(uuid: UUID_NULL)
    private let emptyListHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    init() throws {
        TestConfiguration.configure()
        Self.registerTrackingHostResolver {
            TrackingHostResolver(persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
                                 declaredTrackingDomains: ["api-tracking.mindbox.ru"])
        }

        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.reset()
        coreController = DI.injectOrFail(CoreController.self)
        controllerQueue = coreController.controllerQueue
        databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try databaseRepository.erase()
        EmbeddedBlockAppPresence.shared.reset()
    }

    @Test("Zeros before any accepted value create nothing, a later grant creates one event")
    func zerosBeforeAcceptanceCreateNothingAGrantCreatesOne() async throws {
        try await initialize()

        await update(zeros)
        #expect(try trackingIdsEventCount() == 0)

        await update(UUID())
        #expect(try trackingIdsEventCount() == 1)

        cleanup()
    }

    @Test("The same id again before acceptance creates nothing")
    func sameIdAgainBeforeAcceptanceCreatesNothing() async throws {
        try await initialize()
        let id = UUID()

        await update(id)
        await update(id)

        #expect(try trackingIdsEventCount() == 1)
        cleanup()
    }

    @Test("An id the server already accepted creates nothing")
    func acceptedIdCreatesNothing() async throws {
        try await initialize()
        let id = UUID()
        accept(Self.hash(of: id))

        await update(id)

        #expect(try trackingIdsEventCount() == 0)
        cleanup()
    }

    @Test("Revoke after an accepted id creates an empty-list event, a re-grant creates another")
    func revokeAfterAcceptedIdCreatesAnEvent() async throws {
        try await initialize()
        accept(Self.hash(of: UUID()))

        await update(zeros)
        #expect(try trackingIdsEventCount() == 1)

        await update(UUID())
        #expect(try trackingIdsEventCount() == 2)

        cleanup()
    }

    @Test("Revoke with an accepted empty list creates nothing")
    func revokeWithAcceptedEmptyListCreatesNothing() async throws {
        try await initialize()
        accept(emptyListHash)

        await update(nil)

        #expect(try trackingIdsEventCount() == 0)
        cleanup()
    }

    @Test("A re-grant of the accepted id after a revoke in the same launch creates another event")
    func regrantOfAcceptedIdAfterRevokeCreatesAnotherEvent() async throws {
        try await initialize()
        let id = UUID()
        accept(Self.hash(of: id))

        await update(nil)
        #expect(try trackingIdsEventCount() == 1)

        await update(id)
        #expect(try trackingIdsEventCount() == 2)

        cleanup()
    }

    @Test("A revoke after a grant requested in the same launch creates an event, though nothing was accepted")
    func revokeAfterRequestedGrantCreatesAnEvent() async throws {
        try await initialize()
        let id = UUID()

        await update(id)
        await update(nil)
        #expect(try trackingIdsEventCount() == 2)

        await update(id)
        #expect(try trackingIdsEventCount() == 3)

        cleanup()
    }

    @Test("Back-to-back setter calls are each claimed with their own value")
    func backToBackSetterCallsAreClaimedWithTheirOwnValues() async throws {
        try await initialize()
        let id = UUID()
        await update(id)
        #expect(try trackingIdsEventCount() == 1)

        controllerQueue.suspend()
        coreController.advertisingIdentifierDidUpdate(nil)
        coreController.advertisingIdentifierDidUpdate(id)
        controllerQueue.resume()
        await drainControllerQueue()

        #expect(try trackingIdsEventCount() == 3)
        cleanup()
    }

    @Test("A setter call before initialization on an installed device waits for the initialization")
    func setterBeforeInitializationOnAnInstalledDeviceWaitsForIt() async throws {
        try await initialize()
        SessionTemporaryStorage.shared.isInitializationCalled = false

        await update(UUID())
        #expect(try trackingIdsEventCount() == 0)

        try await initialize()
        #expect(try trackingIdsEventCount() == 1)
        cleanup()
    }

    @Test("A revoke in the next launch after a grant whose answer never came sends an empty list")
    func revokeInTheNextLaunchAfterAnUnconfirmedGrantSendsAnEmptyList() async throws {
        try await initialize()
        await update(UUID())
        #expect(try trackingIdsEventCount() == 1)

        #expect(nextLaunchClaims(zeros))
        cleanup()
    }

    @Test("The accepted id in the next launch after an unconfirmed change is sent again")
    func acceptedIdInTheNextLaunchAfterAnUnconfirmedChangeIsSentAgain() async throws {
        try await initialize()
        let accepted = UUID()
        accept(Self.hash(of: accepted))
        await update(UUID())
        #expect(try trackingIdsEventCount() == 1)

        #expect(nextLaunchClaims(accepted))
        cleanup()
    }

    @Test("A Keepalive that finds a tracking host the setter call lacked claims the id first, so a revoke in the next launch clears it")
    func keepaliveWithANewTrackingHostClaimsTheIdFirst() async throws {
        try await initialize()
        storage.operationsDomainFromConfig = "proxy.client.ru"
        await update(UUID())
        #expect(try trackingIdsEventCount() == 0)

        storage.operationsDomainFromConfig = nil
        storage.lastInfoUpdateDate = nil
        NotificationCenter.default.post(
            name: .receivedPushTokenKeepaliveFromTheMobileConfig,
            object: nil,
            userInfo: [Constants.Notification.pushTokenKeepalive: "0.00:00:01"]
        )
        await drainControllerQueue()

        #expect(try trackingIdsEventCount() == 1)
        #expect(nextLaunchClaims(zeros))
        cleanup()
    }

    @Test("Initialization sends an id set before it once; a repeated initialization sends nothing")
    func initializationSendsAPendingIdOnce() async throws {
        await update(UUID())
        #expect(try trackingIdsEventCount() == 0)

        try await initialize()
        #expect(try trackingIdsEventCount() == 1)

        try await initialize()
        #expect(try trackingIdsEventCount() == 1)

        cleanup()
    }

    @Test("A repeated initialization with a changed endpoint sends the id again for the new installation")
    func reinitializationWithAChangedEndpointSendsTheIdAgain() async throws {
        try await initialize()
        await update(UUID())
        #expect(try trackingIdsEventCount() == 1)

        coreController.initialization(configuration: try MBConfiguration(endpoint: "another-endpoint", domain: "api.mindbox.ru"))
        await drainControllerQueue()

        #expect(try trackingIdsEventCount() == 1)
        #expect(nextLaunchClaims(zeros))
        cleanup()
    }

    @Test("A revoke after a repeated initialization with a changed endpoint clears the id the old installation sent")
    func revokeAfterReinitializationWithAChangedEndpointSendsAnEmptyList() async throws {
        try await initialize()
        accept(Self.hash(of: UUID()))

        coreController.initialization(configuration: try MBConfiguration(endpoint: "another-endpoint", domain: "api.mindbox.ru"))
        await drainControllerQueue()
        #expect(try trackingIdsEventCount() == 0)

        await update(zeros)
        #expect(try trackingIdsEventCount() == 1)
        cleanup()
    }

    @Test("The setter's InfoUpdated leaves the Keepalive clock alone")
    func setterEventLeavesTheKeepaliveClockAlone() async throws {
        try await initialize()
        let lastInfoUpdate = Date(timeIntervalSince1970: 1_700_000_000)
        storage.lastInfoUpdateDate = lastInfoUpdate

        await update(UUID())

        #expect(try trackingIdsEventCount() == 1)
        #expect(storage.lastInfoUpdateDate == lastInfoUpdate)
        cleanup()
    }

    @Test("The setter's event sent through the SDK's event repository stores the hash of the id it carried")
    func setterEventSentThroughTheRepositoryStoresItsHash() async throws {
        try await initialize()
        let id = UUID()
        await update(id)
        let event = try #require(try databaseRepository.query(fetchLimit: 100).first { $0.type == .trackingIdsUpdated })

        await withCheckedContinuation { continuation in
            DI.injectOrFail(EventRepository.self).send(event: event) { _ in continuation.resume() }
        }

        #expect(TrackingIdsRecord.reference(in: storage) == .hash(Self.hash(of: id)))
        cleanup()
    }

    @Test("Initialization reports a main host declared as tracking before any setter call")
    func initializationReportsAMainHostDeclaredAsTracking() async throws {
        let reports = Locked(wrappedValue: 0)
        Self.registerTrackingHostResolver {
            TrackingHostResolver(persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
                                 declaredTrackingDomains: ["api.mindbox.ru"],
                                 misconfigurationHandler: { _ in reports.mutate { $0 += 1 } })
        }
        let controllerWithReportingResolver = DI.injectOrFail(CoreController.self)

        controllerWithReportingResolver.initialization(configuration: try MBConfiguration(plistName: "TestConfig1"))
        await withCheckedContinuation { continuation in
            controllerWithReportingResolver.controllerQueue.async { continuation.resume() }
        }

        #expect(reports.wrappedValue == 1)
        cleanup()
    }

    @Test("Configured but not installed: a granted id creates nothing until the installation sends it")
    func notInstalledDefersAGrantedIdToInstallation() async throws {
        storage.configuration = try MBConfiguration(plistName: "TestConfig1")
        try #require(!storage.isInstalled)
        try #require(DI.injectOrFail(TrackingHostResolver.self).trackingHost == "api-tracking.mindbox.ru")

        await update(UUID())
        #expect(try trackingIdsEventCount() == 0)

        try await initialize()
        #expect(try trackingIdsEventCount() == 1)

        cleanup()
    }

    private static func registerTrackingHostResolver(_ make: @escaping () -> TrackingHostResolver) {
        let baseBuilder = MBInject.buildTestContainer
        MBInject.buildTestContainer = {
            let container = baseBuilder()
            container.register(TrackingHostResolver.self) { make() }
            return container
        }
        MBInject.mode = .test
        MBInject.buildTestContainer = baseBuilder
    }

    private func initialize() async throws {
        coreController.initialization(configuration: try MBConfiguration(plistName: "TestConfig1"))
        await drainControllerQueue()
    }

    private func update(_ identifier: UUID?) async {
        coreController.advertisingIdentifierDidUpdate(identifier)
        await drainControllerQueue()
    }

    private func nextLaunchClaims(_ identifier: UUID?) -> Bool {
        let trackingIdsResolver = TrackingIdsResolver()
        trackingIdsResolver.update(identifier: identifier)
        return TrackingIdsChangeDetector(trackingIdsResolver: trackingIdsResolver,
                                         trackingHostResolver: DI.injectOrFail(TrackingHostResolver.self),
                                         persistenceStorage: storage).claimPendingChange()
    }

    private func accept(_ hash: String) {
        storage.trackingIdsRecord = TrackingIdsRecord(instanceId: storage.applicationInstanceId, reference: .hash(hash)).rawValue
    }

    private func drainControllerQueue() async {
        await withCheckedContinuation { continuation in
            controllerQueue.async {
                continuation.resume()
            }
        }
    }

    private func trackingIdsEventCount() throws -> Int {
        try databaseRepository.query(fetchLimit: 100).filter { $0.type == .trackingIdsUpdated }.count
    }

    private static func hash(of identifier: UUID) -> String {
        TrackingIdsAttachment.identifiers([TrackingId(type: TrackingId.appleType, value: identifier.uuidString)], trackingHost: "api-tracking.mindbox.ru").hash
    }

    private func cleanup() {
        storage.reset()
        storage.userVisitCount = 0
        SessionTemporaryStorage.shared.erase()
        SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = false
    }
}
