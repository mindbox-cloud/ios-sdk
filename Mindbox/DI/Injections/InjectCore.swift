//
//  InjectCore.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension MBContainer {
    func registerCore() -> Self {
//        register(CoreController.self, scope: .container) {
//            let instanceFactory = container.injectOrFail(InstanceFactory.self)
//            return CoreController(
//                persistenceStorage: container.injectOrFail(PersistenceStorage.self),
//                utilitiesFetcher: container.injectOrFail(UtilitiesFetcher.self),
//                databaseRepository: container.injectOrFail(MBDatabaseRepository.self),
//                guaranteedDeliveryManager: container.injectOrFail(GuaranteedDeliveryManager.self),
//                trackVisitManager: instanceFactory.makeTrackVisitManager(),
//                sessionManager: container.injectOrFail(MBSessionManager.self),
//                inAppMessagesManager: container.injectOrFail(InAppCoreManagerProtocol.self),
//                uuidDebugService: container.injectOrFail(UUIDDebugService.self),
//                userVisitManager: container.injectOrFail(UserVisitManagerProtocol.self))
//        }
        
        register(GuaranteedDeliveryManager.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
            let eventRepository = DI.injectOrFail(EventRepository.self)
            return GuaranteedDeliveryManager(
                persistenceStorage: persistenceStorage,
                databaseRepository: databaseRepository,
                eventRepository: eventRepository
            )
        }
        
        register(InAppConfigurationMapperProtocol.self) {
            let inappFilterService = DI.injectOrFail(InappFilterProtocol.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            let dataFacade = DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self)
            return InAppConfigutationMapper(inappFilterService: inappFilterService,
                                            targetingChecker: targetingChecker,
                                            dataFacade: dataFacade)
        }
        
        register(InAppConfigurationManagerProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppConfigurationManager(
                inAppConfigAPI: InAppConfigurationAPI(persistenceStorage: persistenceStorage),
                inAppConfigRepository: InAppConfigurationRepository(),
                inAppConfigurationMapper: DI.injectOrFail(InAppConfigurationMapperProtocol.self),
                persistenceStorage: persistenceStorage)
        }
                                            
        return self
    }
}
