//
//  DependencyContainer.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 22.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol DependencyContainer {
    var utilitiesFetcher: UtilitiesFetcher { get }
    var persistenceStorage: PersistenceStorage { get }
    var databaseLoader: DataBaseLoader { get }
    var databaseRepository: MBDatabaseRepository { get }
    var guaranteedDeliveryManager: GuaranteedDeliveryManager { get }
    var authorizationStatusProvider: UNAuthorizationStatusProviding { get }
    var instanceFactory: InstanceFactory { get }
    var sessionManager: SessionManager { get }
}

protocol InstanceFactory {
    func makeNetworkFetcher() -> NetworkFetcher
    func makeEventRepository() -> EventRepository
    func makeTrackVisitManager() -> TrackVisitManager
}
