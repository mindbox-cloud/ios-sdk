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
//
//        register(PersistenceStorage.self) {
//            let utilitiesFetcher = container.injectOrFail(UtilitiesFetcher.self)
//            let defaults = UserDefaults(suiteName: utilitiesFetcher.applicationGroupIdentifier)!
//            return MBPersistenceStorage(defaults: defaults)
//        }
//
        register(TimerManager.self) {
            TimerManager()
        }
//
//        register(UserVisitManagerProtocol.self, scope: .container) {
//            UserVisitManager(persistenceStorage: container.inject(PersistenceStorage.self)!)
//        }
//        
        register(MindboxPushValidator.self, scope: .transient) {
            MindboxPushValidator()
        }
//        
//        
//        register(TTLValidationProtocol.self) {
//            let persistenceStorage = MBContainer.injectOrFail(PersistenceStorage.self)
//            return TTLValidationService(persistenceStorage: persistenceStorage)
//        }
//        
//        register(InappFrequencyValidator.self, scope: .container) {
//            let persistenceStorage = MBContainer.injectOrFail(PersistenceStorage.self)
//            return InappFrequencyValidator(persistenceStorage: persistenceStorage)
//        }
//        
//        register(InAppTargetingCheckerProtocol.self, scope: .container) {
//            let persistenceStorage = MBContainer.injectOrFail(PersistenceStorage.self)
//            return InAppTargetingChecker(persistenceStorage: persistenceStorage)
//        }
//        
//        register(DataBaseLoader.self, scope: .container) {
//            let utilitiesFetcher = MBContainer.injectOrFail(UtilitiesFetcher.self)
//            return try! DataBaseLoader(applicationGroupIdentifier: utilitiesFetcher.applicationGroupIdentifier)
//        }
//        
//        register(MBDatabaseRepository.self, scope: .container) {
//            let databaseLoader = MBContainer.injectOrFail(DataBaseLoader.self)
//            let persistentContainer = try! databaseLoader.loadPersistentContainer()
//            return try! MBDatabaseRepository(persistentContainer: persistentContainer)
//        }
//        
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
//        
//        register(ImageDownloader.self, scope: .container) {
//            let persistenceStorage = MBContainer.injectOrFail(PersistenceStorage.self)
//            return URLSessionImageDownloader(persistenceStorage: persistenceStorage)
//        }
//        
//        register(ImageDownloadServiceProtocol.self, scope: .container) {
//            let imageDownloader = MBContainer.injectOrFail(ImageDownloader.self)
//            return ImageDownloadService(imageDownloader: imageDownloader)
//        }
//
//        register(GeoServiceProtocol.self, scope: .container) {
//            let instanceFactory = MBContainer.injectOrFail(InstanceFactory.self)
//            let targetingChecker = MBContainer.injectOrFail(InAppTargetingCheckerProtocol.self)
//            return GeoService(fetcher: instanceFactory.makeNetworkFetcher(),
//                              targetingChecker: targetingChecker)
//        }
//        
//        register(SegmentationServiceProtocol.self, scope: .container) {
//            let inAppTargetingChecker = MBContainer.injectOrFail(InAppTargetingCheckerProtocol.self)
//            return SegmentationService(customerSegmentsAPI: .live,
//                                       targetingChecker: inAppTargetingChecker)
//        }
//        
//        return self
//    }
//    
//    func registerInstanceFactory() -> Self {
//        register(InstanceFactory.self) {
//            return MBInstanceFactory(persistenceStorage: MBContainer.injectOrFail(PersistenceStorage.self),
//                                     utilitiesFetcher: MBContainer.injectOrFail(UtilitiesFetcher.self),
//                                     databaseRepository: MBContainer.injectOrFail(MBDatabaseRepository.self))
//        }
//        
        return self
    }
}
