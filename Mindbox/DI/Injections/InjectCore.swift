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
        register(CoreController.self, scope: .container) {
            let instanceFactory = container.injectOrFail(InstanceFactory.self)
            return CoreController(
                persistenceStorage: container.injectOrFail(PersistenceStorage.self),
                utilitiesFetcher: container.injectOrFail(UtilitiesFetcher.self),
                notificationStatusProvider: container.injectOrFail(UNAuthorizationStatusProviding.self),
                databaseRepository: container.injectOrFail(MBDatabaseRepository.self),
                guaranteedDeliveryManager: container.injectOrFail(GuaranteedDeliveryManager.self),
                trackVisitManager: instanceFactory.makeTrackVisitManager(),
                sessionManager: container.injectOrFail(MBSessionManager.self),
                inAppMessagesManager: container.injectOrFail(InAppCoreManagerProtocol.self),
                uuidDebugService: container.injectOrFail(UUIDDebugService.self),
                userVisitManager: container.injectOrFail(UserVisitManagerProtocol.self))
        }
        
        return self
    }
}
