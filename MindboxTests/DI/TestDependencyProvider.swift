//
//  DITest.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 28.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//


import XCTest
@testable import Mindbox

final class TestDependencyProvider: DependencyContainer {
    let inAppMessagesManager: InAppCoreManagerProtocol
    let utilitiesFetcher: UtilitiesFetcher
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    var inappMessageEventSender: InappMessageEventSender
    var inappFilterService: InappFilterProtocol
    
    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)

        let eventRepository = DI.injectOrFail(EventRepository.self)
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: eventRepository
        )
        inAppMessagesManager = InAppCoreManagerMock()
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)

        inappFilterService = InappsFilterService(persistenceStorage: persistenceStorage,
                                                 variantsFilter: DI.injectOrFail(VariantFilterProtocol.self),
                                                 sdkVersionValidator: DI.injectOrFail(SDKVersionValidator.self))
    }
}

