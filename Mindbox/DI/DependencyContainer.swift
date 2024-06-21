//
//  DependencyContainer.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 22.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

protocol DependencyContainer {
    var utilitiesFetcher: UtilitiesFetcher { get }
    var persistenceStorage: PersistenceStorage { get }
    var databaseLoader: DataBaseLoader { get }
    var databaseRepository: MBDatabaseRepository { get }
    var guaranteedDeliveryManager: GuaranteedDeliveryManager { get }
    var authorizationStatusProvider: UNAuthorizationStatusProviding { get }
    var instanceFactory: InstanceFactory { get }
    var sessionManager: SessionManager { get }
    var inAppTargetingChecker: InAppTargetingChecker { get }
    var inAppMessagesManager: InAppCoreManagerProtocol { get }
    var uuidDebugService: UUIDDebugService { get }
    var inappMessageEventSender: InappMessageEventSender { get }
    var sdkVersionValidator: SDKVersionValidator { get }
    var geoService: GeoServiceProtocol { get }
    var segmentationSevice: SegmentationServiceProtocol { get }
    var imageDownloadService: ImageDownloadServiceProtocol { get }
    var urlExtractorService: VariantImageUrlExtractorService { get }
    var inappFilterService: InappFilterProtocol { get }
    var pushValidator: MindboxPushValidator { get }
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol { get }
    var userVisitManager: UserVisitManagerProtocol { get }
    var ttlValidationService: TTLValidationProtocol { get }
    var frequencyValidator: InappFrequencyValidator { get }
}

protocol InstanceFactory {
    func makeNetworkFetcher() -> NetworkFetcher
    func makeEventRepository() -> EventRepository
    func makeTrackVisitManager() -> TrackVisitManager
}
