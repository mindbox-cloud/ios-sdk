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
    let inAppMessagesManager: InAppCoreManagerProtocol
    var inappMessageEventSender: InappMessageEventSender

    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.migrateShownInAppsIds()
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        
        inAppMessagesManager = InAppCoreManager(
            configManager: DI.injectOrFail(InAppConfigurationManagerProtocol.self),
            presentationManager: DI.injectOrFail(InAppPresentationManagerProtocol.self),
            persistenceStorage: persistenceStorage
        )
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)        
    }
}
