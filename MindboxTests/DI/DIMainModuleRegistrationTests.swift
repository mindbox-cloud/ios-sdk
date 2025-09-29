//
//  DIMainModuleRegistrationTests.swift
//  MindboxTests
//
//  Created by vailence on 11.07.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class DIMainModuleRegistrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MBInject.mode = .standard
    }

    func testCoreControllerIsRegistered() {
        let coreController: CoreController? = DI.inject(CoreController.self)
        XCTAssertNotNil(coreController)
    }

    func testGuaranteedDeliveryManagerIsRegistered() {
        let manager: GuaranteedDeliveryManager? = DI.inject(GuaranteedDeliveryManager.self)
        XCTAssertNotNil(manager)
    }

    func testInAppConfigurationMapperIsRegistered() {
        let mapper: InappMapperProtocol? = DI.inject(InappMapperProtocol.self)
        XCTAssertNotNil(mapper)
    }

    func testInAppConfigurationManagerIsRegistered() {
        let manager: InAppConfigurationManagerProtocol? = DI.inject(InAppConfigurationManagerProtocol.self)
        XCTAssertNotNil(manager)
    }

    func testInAppCoreManagerIsRegistered() {
        let manager: InAppCoreManagerProtocol? = DI.inject(InAppCoreManagerProtocol.self)
        XCTAssertNotNil(manager)
    }

    func testUUIDDebugServiceIsRegistered() {
        let service: UUIDDebugService? = DI.inject(UUIDDebugService.self)
        XCTAssertNotNil(service)
    }

    func testUNAuthorizationStatusProviderIsRegistered() {
        let provider: UNAuthorizationStatusProviding? = DI.inject(UNAuthorizationStatusProviding.self)
        XCTAssertNotNil(provider)
    }

    func testSDKVersionValidatorIsRegistered() {
        let validator: SDKVersionValidator? = DI.inject(SDKVersionValidator.self)
        XCTAssertNotNil(validator)
    }

    func testPersistenceStorageIsRegistered() {
        let storage: PersistenceStorage? = DI.inject(PersistenceStorage.self)
        XCTAssertNotNil(storage)
    }

    func testDatabaseRepositoryIsRegistered() {
        let repository: DatabaseRepositoryProtocol? = DI.inject(DatabaseRepositoryProtocol.self)
        XCTAssertNotNil(repository)
    }

    func testImageDownloadServiceIsRegistered() {
        let service: ImageDownloadServiceProtocol? = DI.inject(ImageDownloadServiceProtocol.self)
        XCTAssertNotNil(service)
    }

    func testNetworkFetcherIsRegistered() {
        let fetcher: NetworkFetcher? = DI.inject(NetworkFetcher.self)
        XCTAssertNotNil(fetcher)
    }

    func testInAppConfigurationDataFacadeIsRegistered() {
        let facade: InAppConfigurationDataFacadeProtocol? = DI.inject(InAppConfigurationDataFacadeProtocol.self)
        XCTAssertNotNil(facade)
    }

    func testSessionManagerIsRegistered() {
        let manager: SessionManager? = DI.inject(SessionManager.self)
        XCTAssertNotNil(manager)
    }

    func testSDKLogsManagerIsRegistered() {
        let manager: SDKLogsManagerProtocol? = DI.inject(SDKLogsManagerProtocol.self)
        XCTAssertNotNil(manager)
    }

    // Тесты для UtilitiesServices
    func testUtilitiesFetcherIsRegistered() {
        let fetcher: UtilitiesFetcher? = DI.inject(UtilitiesFetcher.self)
        XCTAssertNotNil(fetcher)
    }

    func testTimerManagerIsRegistered() {
        let timerManager: TimerManager? = DI.inject(TimerManager.self)
        XCTAssertNotNil(timerManager)
    }

    func testUserVisitManagerIsRegistered() {
        let manager: UserVisitManagerProtocol? = DI.inject(UserVisitManagerProtocol.self)
        XCTAssertNotNil(manager)
    }

    func testMindboxPushValidatorIsRegistered() {
        let validator: MindboxPushValidator? = DI.inject(MindboxPushValidator.self)
        XCTAssertNotNil(validator)
    }

    func testInAppTargetingCheckerIsRegistered() {
        let checker: InAppTargetingCheckerProtocol? = DI.inject(InAppTargetingCheckerProtocol.self)
        XCTAssertNotNil(checker)
    }

    func testDataBaseLoaderIsRegistered() {
        let loader: DatabaseLoaderProtocol? = DI.inject(DatabaseLoaderProtocol.self)
        XCTAssertNotNil(loader)
    }

    func testVariantImageUrlExtractorServiceIsRegistered() {
        let extractor: VariantImageUrlExtractorServiceProtocol? = DI.inject(VariantImageUrlExtractorServiceProtocol.self)
        XCTAssertNotNil(extractor)
    }

    func testGeoServiceIsRegistered() {
        let service: GeoServiceProtocol? = DI.inject(GeoServiceProtocol.self)
        XCTAssertNotNil(service)
    }

    func testSegmentationServiceIsRegistered() {
        let service: SegmentationServiceProtocol? = DI.inject(SegmentationServiceProtocol.self)
        XCTAssertNotNil(service)
    }

    func testEventRepositoryIsRegistered() {
        let repository: EventRepository? = DI.inject(EventRepository.self)
        XCTAssertNotNil(repository)
    }

    func testTrackVisitManagerIsRegistered() {
        let commonTrackManager: TrackVisitCommonTrackProtocol? = DI.inject(TrackVisitManagerProtocol.self)
        XCTAssertNotNil(commonTrackManager)
        
        let specificTrackManager: TrackVisitSpecificTrackProtocol? = DI.inject(TrackVisitManagerProtocol.self)
        XCTAssertNotNil(specificTrackManager)
    }

    func testInappMessageEventSenderIsRegistered() {
        let sender: InappMessageEventSender? = DI.inject(InappMessageEventSender.self)
        XCTAssertNotNil(sender)
    }

    func testClickNotificationManagerIsRegistered() {
        let manager: ClickNotificationManager? = DI.inject(ClickNotificationManager.self)
        XCTAssertNotNil(manager)
    }

    func testABTestDeviceMixerIsRegistered() {
        let mixer: ABTestDeviceMixer? = DI.inject(ABTestDeviceMixer.self)
        XCTAssertNotNil(mixer)
    }

    func testABTestVariantsValidatorIsRegistered() {
        let validator: ABTestVariantsValidator? = DI.inject(ABTestVariantsValidator.self)
        XCTAssertNotNil(validator)
    }

    func testABTestValidatorIsRegistered() {
        let validator: ABTestValidator? = DI.inject(ABTestValidator.self)
        XCTAssertNotNil(validator)
    }

    func testLayerActionFilterIsRegistered() {
        let filter: LayerActionFilterProtocol? = DI.inject(LayerActionFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testLayersSourceFilterIsRegistered() {
        let filter: LayersSourceFilterProtocol? = DI.inject(LayersSourceFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testLayersFilterIsRegistered() {
        let filter: LayersFilterProtocol? = DI.inject(LayersFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testElementsSizeFilterIsRegistered() {
        let filter: ElementsSizeFilterProtocol? = DI.inject(ElementsSizeFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testElementsColorFilterIsRegistered() {
        let filter: ElementsColorFilterProtocol? = DI.inject(ElementsColorFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testElementsPositionFilterIsRegistered() {
        let filter: ElementsPositionFilterProtocol? = DI.inject(ElementsPositionFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testElementsFilterIsRegistered() {
        let filter: ElementsFilterProtocol? = DI.inject(ElementsFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testContentPositionFilterIsRegistered() {
        let filter: ContentPositionFilterProtocol? = DI.inject(ContentPositionFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testVariantFilterIsRegistered() {
        let filter: VariantFilterProtocol? = DI.inject(VariantFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    func testInappFilterIsRegistered() {
        let filter: InappFilterProtocol? = DI.inject(InappFilterProtocol.self)
        XCTAssertNotNil(filter)
    }

    // Тесты для InappPresentation
    func testInAppMessagesTrackerIsRegistered() {
        let tracker: InAppMessagesTracker? = DI.inject(InAppMessagesTracker.self)
        XCTAssertNotNil(tracker)
    }

    func testPresentationDisplayUseCaseIsRegistered() {
        let useCase: PresentationDisplayUseCase? = DI.inject(PresentationDisplayUseCase.self)
        XCTAssertNotNil(useCase)
    }

    func testUseCaseFactoryIsRegistered() {
        let factory: UseCaseFactoryProtocol? = DI.inject(UseCaseFactoryProtocol.self)
        XCTAssertNotNil(factory)
    }

    func testInAppActionHandlerIsRegistered() {
        let handler: InAppActionHandlerProtocol? = DI.inject(InAppActionHandlerProtocol.self)
        XCTAssertNotNil(handler)
    }

    func testInAppPresentationManagerIsRegistered() {
        let manager: InAppPresentationManagerProtocol? = DI.inject(InAppPresentationManagerProtocol.self)
        XCTAssertNotNil(manager)
    }

    func testMigrationManagerIsRegistered() {
        let manager: MigrationManagerProtocol? = DI.inject(MigrationManagerProtocol.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is MigrationManager)
    }

    func testInappSessionManagerIsRegistered() {
        let manager: InappSessionManagerProtocol? = DI.inject(InappSessionManagerProtocol.self)
        XCTAssertNotNil(manager)
    }
    
    func testInappPresentationValidatorIsRegistered() {
        let manager: InAppPresentationValidatorProtocol? = DI.inject(InAppPresentationValidatorProtocol.self)
        XCTAssertNotNil(manager)
    }
    
    func testInappTrackingServiceIsRegistered() {
        let manager: InAppTrackingServiceProtocol? = DI.inject(InAppTrackingServiceProtocol.self)
        XCTAssertNotNil(manager)
    }
    
    func test_InappScheduleManagerIsRegistered() {
        let manager: InappScheduleManagerProtocol? = DI.inject(InappScheduleManagerProtocol.self)
        XCTAssertNotNil(manager)
    }
}
