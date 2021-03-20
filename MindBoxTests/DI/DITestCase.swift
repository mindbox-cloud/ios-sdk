//
//  DITest.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 28.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//


import XCTest
@testable import MindBox

final class TestDIManager: DIContainer {
    
    let utilitiesFetcher: UtilitiesFetcher
    let persistenceStorage: PersistenceStorage
    let databaseLoader: DataBaseLoader
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let authorizationStatusProvider: UNAuthorizationStatusProviding
    let newInstanceDependency: NewInstanceDependency
    static let logger: ILogger = MBLogger()
    
    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        persistenceStorage = MockPersistenceStorage()
        newInstanceDependency = MockNewInstanceDependency(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: utilitiesFetcher
        )
        databaseLoader = try DataBaseLoader()
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        databaseRepository = try MBDatabaseRepository(persistentContainer: persistentContainer)
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: newInstanceDependency.makeEventRepository()
        )
        authorizationStatusProvider = MockUNAuthorizationStatusProvider(status: .authorized)
    }

}

class MockNewInstanceDependency: NewInstanceDependency {
    
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher

    init(persistenceStorage: PersistenceStorage, utilitiesFetcher: UtilitiesFetcher) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
    }

    func makeNetworkFetcher() -> NetworkFetcher {
        return MockNetworkFetcher()
    }

    func makeEventRepository() -> EventRepository {
        return MBEventRepository(
            fetcher: makeNetworkFetcher(),
            persistenceStorage: persistenceStorage
        )
    }
}

