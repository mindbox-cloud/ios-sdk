//
//  DIManager.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import CoreData
import Foundation
import UIKit

final class DependencyProvider: DependencyContainer {
    let utilitiesFetcher: UtilitiesFetcher
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let inAppMessagesManager: InAppCoreManagerProtocol
    var inappMessageEventSender: InappMessageEventSender
    var inappFilterService: InappFilterProtocol

    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.migrateShownInAppsIds()
        let inAppTargetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)

        let eventRepository = DI.injectOrFail(EventRepository.self)
        
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: eventRepository
        )
        let logsManager = SDKLogsManager(persistenceStorage: persistenceStorage, eventRepository: eventRepository)
        
        inappFilterService = InappsFilterService(persistenceStorage: persistenceStorage,
                                                 variantsFilter: DI.injectOrFail(VariantFilterProtocol.self),
                                                 sdkVersionValidator: DI.injectOrFail(SDKVersionValidator.self))
        
        inAppMessagesManager = InAppCoreManager(
            configManager: InAppConfigurationManager(
                inAppConfigAPI: InAppConfigurationAPI(persistenceStorage: persistenceStorage),
                inAppConfigRepository: InAppConfigurationRepository(),
                inAppConfigurationMapper: InAppConfigutationMapper(inappFilterService: inappFilterService,
                                                                   targetingChecker: inAppTargetingChecker,
                                                                   dataFacade: DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self)),
                logsManager: logsManager,
            persistenceStorage: persistenceStorage),
            presentationManager: DI.injectOrFail(InAppPresentationManagerProtocol.self),
            persistenceStorage: persistenceStorage
        )
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)        
    }
}
