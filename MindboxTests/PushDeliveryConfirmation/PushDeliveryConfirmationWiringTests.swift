//
//  PushDeliveryConfirmationWiringTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UIKit
@_spi(Internal) @testable import Mindbox

@Suite("Delivery confirmation queue wiring", .serialized)
final class PushDeliveryConfirmationWiringTests {

    private let folder: QueueTestFolder
    private let sender = QueueTestSender()
    private let clock = QueueTestClock(now: Date(timeIntervalSince1970: 1_800_000_000))
    private let persistenceStorage = MockPersistenceStorage()
    private let databaseRepository: MockDatabaseRepository
    private let manager: GuaranteedDeliveryManager
    private let controllerQueue = DispatchQueue(label: "test-delivery-confirmation-wiring")
    private let savedIsInitializationCalled: Bool
    private let savedIsInstalledBeforeInit: Bool
    private let base: Int64 = 1_800_000_000_000
    private var queue: PushDeliveryConfirmationQueue?
    private var coreController: CoreController?

    init() throws {
        folder = try QueueTestFolder()
        databaseRepository = try MockDatabaseRepository(inMemory: true)
        manager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: DI.injectOrFail(EventRepository.self)
        )
        savedIsInitializationCalled = SessionTemporaryStorage.shared.isInitializationCalled
        savedIsInstalledBeforeInit = SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK
    }

    deinit {
        SessionTemporaryStorage.shared.isInitializationCalled = savedIsInitializationCalled
        SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = savedIsInstalledBeforeInit
    }

    private func makeController(folder: QueueTestFolder?) -> CoreController {
        let queue = makeTestQueue(folder: folder, sender: sender, clock: clock)
        self.queue = queue
        let controller = CoreController(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: DI.injectOrFail(UtilitiesFetcher.self),
            databaseRepository: databaseRepository,
            guaranteedDeliveryManager: manager,
            sessionManager: MockSessionManager(),
            inAppMessagesManager: DI.injectOrFail(InAppCoreManagerProtocol.self),
            uuidDebugService: DI.injectOrFail(UUIDDebugService.self),
            trackingIdsResolver: DI.injectOrFail(TrackingIdsResolver.self),
            trackingHostResolver: DI.injectOrFail(TrackingHostResolver.self),
            pushDeliveryConfirmationQueue: queue,
            controllerQueue: controllerQueue,
            userVisitManager: DI.injectOrFail(UserVisitManagerProtocol.self)
        )
        coreController = controller
        return controller
    }

    private func installedConfiguration() throws -> MBConfiguration {
        let configuration = try MBConfiguration(plistName: "TestConfig1")
        persistenceStorage.configuration = configuration
        persistenceStorage.deviceUUID = UUID().uuidString
        persistenceStorage.installationDate = Date()
        return configuration
    }

    private func initialize(_ controller: CoreController, with configuration: MBConfiguration) async {
        controller.initialization(configuration: configuration)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            controllerQueue.async { continuation.resume() }
        }
    }

    private func becomeActive() {
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @Test("K1: initialization with an unchanged configuration sends the records left by the extension")
    func initializationSendsRecords() async throws {
        let configuration = try installedConfiguration()
        try folder.write("a", receivedAt: base)
        let controller = makeController(folder: folder)

        await initialize(controller, with: configuration)
        await sender.waitForCalls(1)

        #expect(sender.urls == [QueueTestFolder.url("a")])
    }

    @Test("K44: becoming active before initialization sends nothing")
    func becomingActiveBeforeInitialization() async throws {
        try folder.write("a", receivedAt: base)
        _ = makeController(folder: folder)

        becomeActive()
        await queue?.wakeAndWait()

        #expect(sender.calls.isEmpty)
    }

    @Test("K2: becoming active after initialization sends a new record")
    func becomingActiveSendsNewRecord() async throws {
        let configuration = try installedConfiguration()
        let controller = makeController(folder: folder)
        await initialize(controller, with: configuration)
        await queue?.wakeAndWait()
        #expect(sender.calls.isEmpty)

        try folder.write("fresh", receivedAt: base)
        becomeActive()
        await sender.waitForCalls(1)

        #expect(sender.urls == [QueueTestFolder.url("fresh")])
    }

    @Test("K29: a changed endpoint keeps the records and drops the GD event")
    func changedEndpointKeepsRecords() async throws {
        _ = try installedConfiguration()
        let changed = try MBConfiguration(
            endpoint: "another-endpoint",
            domain: "api.mindbox.ru",
            previousInstallationId: "",
            previousDeviceUUID: "",
            subscribeCustomerIfCreated: true
        )
        let event = Event(type: .customEvent, body: BodyEncoder(encodable: CustomEvent(name: "Old", payload: "{}")).body)
        try databaseRepository.create(event: event)
        try folder.write("kept", receivedAt: base)
        let controller = makeController(folder: folder)

        await initialize(controller, with: changed)
        await sender.waitForCalls(1)

        #expect(try databaseRepository.readEvent(by: event.transactionId) == nil)
        #expect(sender.urls == [QueueTestFolder.url("kept")])
    }

    @Test("K30: a GD that cannot schedule operations does not block the confirmation")
    func gdPauseDoesNotBlock() async throws {
        let configuration = try installedConfiguration()
        let controller = makeController(folder: folder)
        await initialize(controller, with: configuration)
        await queue?.wakeAndWait()
        manager.canScheduleOperations = false

        try folder.write("a", receivedAt: base)
        becomeActive()
        await sender.waitForCalls(1)

        #expect(manager.canScheduleOperations == false)
        #expect(sender.urls == [QueueTestFolder.url("a")])
    }

    @Test("K31: an empty App Group identifier gives a queue without storage")
    func emptyAppGroupGivesQueueWithoutStorage() async {
        struct EmptyGroupFetcher: UtilitiesFetcher {
            var appVerson: String? { "1.0.0" }
            var sdkVersion: String? { "test" }
            var hostApplicationName: String? { "cloud.Mindbox.MindboxTests" }
            var applicationGroupIdentifier: String { "" }
            func generateDeviceUUID() -> String { UUID().uuidString }
        }
        let container = MBContainer()
        container.register(UtilitiesFetcher.self) { EmptyGroupFetcher() }
        let registered = container.registerCore()

        let queue = registered.resolve(PushDeliveryConfirmationQueue.self)

        #expect(queue != nil)
        #expect(queue?.hasRecords == false)
        await queue?.enableAndWait()
        await queue?.wakeAndWait()
        #expect(queue?.hasRecords == false)
    }
}
