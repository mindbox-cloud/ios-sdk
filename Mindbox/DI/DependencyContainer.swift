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
    var databaseLoader: DataBaseLoader { get }
    var databaseRepository: MBDatabaseRepository { get }
    var guaranteedDeliveryManager: GuaranteedDeliveryManager { get }
    var instanceFactory: InstanceFactory { get }
    var sessionManager: SessionManager { get }
    var inAppTargetingChecker: InAppTargetingChecker { get }
    var inAppMessagesManager: InAppCoreManagerProtocol { get }
    var inappMessageEventSender: InappMessageEventSender { get }
    var geoService: GeoServiceProtocol { get }
    var segmentationSevice: SegmentationServiceProtocol { get }
    var imageDownloadService: ImageDownloadServiceProtocol { get }
    var inappFilterService: InappFilterProtocol { get }
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol { get }
    var ttlValidationService: TTLValidationProtocol { get }
    var frequencyValidator: InappFrequencyValidator { get }
}

protocol InstanceFactory {
    func makeNetworkFetcher() -> NetworkFetcher
    func makeEventRepository() -> EventRepository
    func makeTrackVisitManager() -> TrackVisitManager
}
