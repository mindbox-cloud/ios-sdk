//
//  InjectReplaceable.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit

extension MBContainer {
    func registerReplaceableUtilities() -> Self {
        register(UUIDDebugService.self) {
            PasteboardUUIDDebugService(
                notificationCenter: NotificationCenter.default,
                currentDateProvider: { return Date() },
                pasteboard: UIPasteboard.general
            )
        }

        register(UNAuthorizationStatusProviding.self, scope: .transient) {
            UNAuthorizationStatusProvider()
        }

        register(SDKVersionValidator.self) {
            SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
        }

        register(PersistenceStorage.self) {
            let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
            guard let defaults = UserDefaults(suiteName: utilitiesFetcher.applicationGroupIdentifier) else {
                fatalError("Failed to create UserDefaults with suite name: \(utilitiesFetcher.applicationGroupIdentifier)")
            }
            return MBPersistenceStorage(defaults: defaults)
        }

        register(MBDatabaseRepository.self) {
            let databaseLoader = DI.injectOrFail(DataBaseLoader.self)

            guard let persistentContainer = try? databaseLoader.loadPersistentContainer(),
                    let dbRepository = try? MBDatabaseRepository(persistentContainer: persistentContainer) else {
                fatalError("Failed to create MBDatabaseRepository")
            }
            return dbRepository
        }

        register(ImageDownloadServiceProtocol.self, scope: .container) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let imageDownloader = URLSessionImageDownloader(persistenceStorage: persistenceStorage)
            return ImageDownloadService(imageDownloader: imageDownloader)
        }

        register(NetworkFetcher.self) {
            let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return MBNetworkFetcher(utilitiesFetcher: utilitiesFetcher, persistenceStorage: persistenceStorage)
        }

        register(InAppConfigurationDataFacadeProtocol.self) {
            let segmentationSevice = DI.injectOrFail(SegmentationServiceProtocol.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            let imageService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)

            return InAppConfigurationDataFacade(segmentationService: segmentationSevice,
                                                targetingChecker: targetingChecker,
                                                imageService: imageService,
                                                tracker: tracker)
        }

        register(SessionManager.self) {
            let trackVisitManager = DI.injectOrFail(TrackVisitManager.self)
            return MBSessionManager(trackVisitManager: trackVisitManager)
        }

        register(SDKLogsManagerProtocol.self, scope: .transient) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let eventRepository = DI.injectOrFail(EventRepository.self)
            return SDKLogsManager(persistenceStorage: persistenceStorage, eventRepository: eventRepository)
        }

        register(InAppCoreManagerProtocol.self) {
            let configManager = DI.injectOrFail(InAppConfigurationManagerProtocol.self)
            let presentationManager = DI.injectOrFail(InAppPresentationManagerProtocol.self)
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppCoreManager(configManager: configManager,
                                    presentationManager: presentationManager,
                                    persistenceStorage: persistenceStorage)
        }

        return self
    }
}
