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

        register(MigrationManagerProtocol.self, scope: .transient) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return MigrationManager(persistenceStorage: persistenceStorage)
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
        
        register(DatabaseLoaderProtocol.self) {
            let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
            
            do {
                let dbLoader = try DatabaseLoader(applicationGroupIdentifier: utilitiesFetcher.applicationGroupIdentifier)
                return dbLoader
            } catch {
                assertionFailure(" Failed to create DatabaseLoader: \(error.localizedDescription). Falling back to StubDBLoader - app in production will run in degraded mode (no on-disk persistence)")
                return StubDatabaseLoader()
            }
        }
        
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

        register(TrackVisitManagerProtocol.self) {
            let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
            let inappSessionManger = DI.injectOrFail(InappSessionManagerProtocol.self)
            return TrackVisitManager(databaseRepository: databaseRepository, inappSessionManager: inappSessionManger)
        }

        register(InappMessageEventSender.self, scope: .transient) {
            let inAppMessagesManager = DI.injectOrFail(InAppCoreManagerProtocol.self)
            return InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)
        }

        register(ClickNotificationManager.self) {
            let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
            return ClickNotificationManager(databaseRepository: databaseRepository)
        }

        return self
    }
}
