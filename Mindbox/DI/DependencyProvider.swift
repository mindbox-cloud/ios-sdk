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
    let persistenceStorage: PersistenceStorage
    let databaseLoader: DataBaseLoader
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let authorizationStatusProvider: UNAuthorizationStatusProviding
    let sessionManager: SessionManager
    let instanceFactory: InstanceFactory
    let inAppTargetingChecker: InAppTargetingChecker
    let inAppMessagesManager: InAppCoreManagerProtocol
    let uuidDebugService: UUIDDebugService
    var sessionTemporaryStorage: SessionTemporaryStorage
    var inappMessageEventSender: InappMessageEventSender
    var geoService: GeoService
    var customerAbMixer: CustomerAbMixer
    var imageDownloaderService: ImageDownloadServiceProtocol
    var segmentationService: SegmentationService

    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        inAppTargetingChecker = InAppTargetingChecker()
        persistenceStorage = MBPersistenceStorage(defaults: UserDefaults(suiteName: utilitiesFetcher.applicationGroupIdentifier)!)
        databaseLoader = try DataBaseLoader(applicationGroupIdentifier: utilitiesFetcher.applicationGroupIdentifier)
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        databaseRepository = try MBDatabaseRepository(persistentContainer: persistentContainer)
        instanceFactory = MBInstanceFactory(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: utilitiesFetcher,
            databaseRepository: databaseRepository
        )
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: instanceFactory.makeEventRepository()
        )
        authorizationStatusProvider = UNAuthorizationStatusProvider()
        sessionManager = SessionManager(trackVisitManager: instanceFactory.makeTrackVisitManager())
        let logsManager = SDKLogsManager(persistenceStorage: persistenceStorage, eventRepository: instanceFactory.makeEventRepository())
        sessionTemporaryStorage = SessionTemporaryStorage()
        geoService = GeoService(fetcher: instanceFactory.makeNetworkFetcher(),
                                    sessionTemporaryStorage: sessionTemporaryStorage,
                                    targetingChecker: inAppTargetingChecker)
        customerAbMixer = CustomerAbMixer()
        imageDownloaderService = ImageDownloadService(imageDownloader:
                                                            URLSessionImageDownloader(persistenceStorage: persistenceStorage))
        segmentationService = SegmentationService(customerSegmentsAPI: .live,
                                                      sessionTemporaryStorage: sessionTemporaryStorage,
                                                      targetingChecker: inAppTargetingChecker)

        inAppMessagesManager = InAppCoreManager(
            configManager: InAppConfigurationManager(
                inAppConfigAPI: InAppConfigurationAPI(persistenceStorage: persistenceStorage),
                inAppConfigRepository: InAppConfigurationRepository(),
                inAppMapper: InAppMapper(segmentationService: segmentationService,
                                         geoService: geoService,
                                         imageDownloadService: imageDownloaderService,
                                         targetingChecker: inAppTargetingChecker,
                                         persistenceStorage: persistenceStorage,
                                         sessionTemporaryStorage: sessionTemporaryStorage,
                                         customerAbMixer: customerAbMixer,
                                         inAppsVersion: inAppsSdkVersion),
                logsManager: logsManager, sessionStorage: sessionTemporaryStorage),
            presentationManager: InAppPresentationManager(
                inAppTracker: InAppMessagesTracker(databaseRepository: databaseRepository)
            ),
            persistenceStorage: persistenceStorage,
            sessionStorage: sessionTemporaryStorage
        )
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager,
                                                          sessionStorage: sessionTemporaryStorage)

        uuidDebugService = PasteboardUUIDDebugService(
            notificationCenter: NotificationCenter.default,
            currentDateProvider: { return Date() },
            pasteboard: UIPasteboard.general
        )
    }
}

class MBInstanceFactory: InstanceFactory {
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let databaseRepository: MBDatabaseRepository

    init(
        persistenceStorage: PersistenceStorage,
        utilitiesFetcher: UtilitiesFetcher,
        databaseRepository: MBDatabaseRepository
    ) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
        self.databaseRepository = databaseRepository
    }

    func makeNetworkFetcher() -> NetworkFetcher {
        return MBNetworkFetcher(
            utilitiesFetcher: utilitiesFetcher,
            persistenceStorage: persistenceStorage
        )
    }

    func makeEventRepository() -> EventRepository {
        return MBEventRepository(
            fetcher: makeNetworkFetcher(),
            persistenceStorage: persistenceStorage
        )
    }

    func makeTrackVisitManager() -> TrackVisitManager {
        return TrackVisitManager(databaseRepository: databaseRepository)
    }
}
