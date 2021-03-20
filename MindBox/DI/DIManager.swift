//
//  DIManager.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

/// Регистрирует DI-объекты
final class DIManager: DIContainer {
    
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
        persistenceStorage = MBPersistenceStorage(defaults: UserDefaults(suiteName: utilitiesFetcher.appGroup)!)
        newInstanceDependency = MBNewInstanceDependency(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: utilitiesFetcher
        )
        databaseLoader = try DataBaseLoader(appGroup: utilitiesFetcher.appGroup)
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        databaseRepository = try MBDatabaseRepository(persistentContainer: persistentContainer)
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: newInstanceDependency.makeEventRepository()
        )
        authorizationStatusProvider = UNAuthorizationStatusProvider()
    }

}

protocol NewInstanceDependency {
    
    func makeNetworkFetcher() -> NetworkFetcher
    func makeEventRepository() -> EventRepository
    
}

protocol DIContainer {
    
    var utilitiesFetcher: UtilitiesFetcher { get }
    var persistenceStorage: PersistenceStorage { get }
    var databaseLoader: DataBaseLoader { get }
    var databaseRepository: MBDatabaseRepository { get }
    var guaranteedDeliveryManager: GuaranteedDeliveryManager { get }
    var authorizationStatusProvider: UNAuthorizationStatusProviding { get }
    var newInstanceDependency: NewInstanceDependency { get }
    static var logger: ILogger { get }
    
}

class MBNewInstanceDependency: NewInstanceDependency {
    
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher

    init(persistenceStorage: PersistenceStorage, utilitiesFetcher: UtilitiesFetcher) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
    }

    func makeNetworkFetcher() -> NetworkFetcher {
        return MBNetworkFetcher(
            utilitiesFetcher: utilitiesFetcher,
            persistenceStorage: persistenceStorage
        )
    }

    func makeEventRepository() -> EventRepository {
        return MBEventRepository(
            fetcher: makeNetworkFetcher(),
            persistenceStorage: persistenceStorage
        )
    }
}
