//
//  InjectUtilities.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension MBContainer {
    func registerUtilitiesServices() -> Self {
        register(UtilitiesFetcher.self) {
            MBUtilitiesFetcher()
        }

        register(TimerManager.self) {
            TimerManager()
        }

        register(UserVisitManagerProtocol.self, scope: .transient) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return UserVisitManager(persistenceStorage: persistenceStorage)
        }
        
        register(MindboxPushValidator.self, scope: .transient) {
            MindboxPushValidator()
        }
        
        register(InAppTargetingCheckerProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppTargetingChecker(persistenceStorage: persistenceStorage)
        }
        
        register(DataBaseLoader.self) {
            let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
            return try! DataBaseLoader(applicationGroupIdentifier: utilitiesFetcher.applicationGroupIdentifier)
        }
//        
//        
//        register(GuaranteedDeliveryManager.self, scope: .container) {
//            let persistenceStorage = MBContainer.injectOrFail(PersistenceStorage.self)
//            let databaseRepository = MBContainer.injectOrFail(MBDatabaseRepository.self)
//            let instanceFactory = MBContainer.injectOrFail(InstanceFactory.self)
//            return GuaranteedDeliveryManager(persistenceStorage: persistenceStorage,
//                                             databaseRepository: databaseRepository,
//                                             eventRepository: instanceFactory.makeEventRepository())
//        }
//        
//        register(MBSessionManager.self, scope: .container) {
//            let instanceFactory = MBContainer.injectOrFail(InstanceFactory.self)
//            return MBSessionManager(trackVisitManager: instanceFactory.makeTrackVisitManager())
//        }
//        
        register(VariantImageUrlExtractorServiceProtocol.self, scope: .transient) {
            VariantImageUrlExtractorService()
        }

        register(GeoServiceProtocol.self, scope: .transient) {
            let networkFetcher = DI.injectOrFail(NetworkFetcher.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            return GeoService(fetcher: networkFetcher,
                              targetingChecker: targetingChecker)
        }
        
        register(SegmentationServiceProtocol.self) {
            let inAppTargetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            return SegmentationService(customerSegmentsAPI: .live,
                                       targetingChecker: inAppTargetingChecker)
        }
        
        register(EventRepository.self) {
            let networkFetcher = DI.injectOrFail(NetworkFetcher.self)
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return MBEventRepository(fetcher: networkFetcher, persistenceStorage: persistenceStorage)
        }
        
        register(TrackVisitManager.self) {
            let databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
            return TrackVisitManager(databaseRepository: databaseRepository)
        }

        return self
    }
}
