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
        register(CoreController.self) {
            CoreController(persistenceStorage: DI.injectOrFail(PersistenceStorage.self),
                           utilitiesFetcher: DI.injectOrFail(UtilitiesFetcher.self),
                           databaseRepository: DI.injectOrFail(DatabaseRepositoryProtocol.self),
                           guaranteedDeliveryManager: DI.injectOrFail(GuaranteedDeliveryManager.self),
                           sessionManager: DI.injectOrFail(SessionManager.self),
                           inAppMessagesManager: DI.injectOrFail(InAppCoreManagerProtocol.self),
                           uuidDebugService: DI.injectOrFail(UUIDDebugService.self),
                           userVisitManager: DI.injectOrFail(UserVisitManagerProtocol.self))
        }

        register(GuaranteedDeliveryManager.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
            let eventRepository = DI.injectOrFail(EventRepository.self)
            return GuaranteedDeliveryManager(
                persistenceStorage: persistenceStorage,
                databaseRepository: databaseRepository,
                eventRepository: eventRepository)
        }

        register(InappMapperProtocol.self, scope: .transient) {
            let inappFilterService = DI.injectOrFail(InappFilterProtocol.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            let dataFacade = DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self)
            return InappMapper(targetingChecker: targetingChecker,
                               inappFilterService: inappFilterService,
                               dataFacade: dataFacade)
        }

        register(InAppConfigurationManagerProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppConfigurationManager(
                inAppConfigAPI: InAppConfigurationAPI(persistenceStorage: persistenceStorage),
                inAppConfigRepository: InAppConfigurationRepository(),
                inappMapper: DI.injectOrFail(InappMapperProtocol.self),
                persistenceStorage: persistenceStorage)
        }
        
        register(CheckNotifWork.self) {
            { [weak core = DI.injectOrFail(CoreController.self)] done in
                core?.checkNotificationStatus { done() }
            }
        }

        return self
    }
}
