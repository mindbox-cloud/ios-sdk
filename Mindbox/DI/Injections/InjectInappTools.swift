//
//  InjectInappTools.swift
//  Mindbox
//
//  Created by vailence on 05.07.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension MBContainer {
    func registerInappTools() -> Self {
        // Layers
        register(LayerActionFilterProtocol.self) {
            LayerActionFilterService()
        }

        register(LayersSourceFilterProtocol.self) {
            LayersSourceFilterService()
        }

        register(LayersFilterProtocol.self) {
            let actionFilter = DI.injectOrFail(LayerActionFilterProtocol.self)
            let sourceFilter = DI.injectOrFail(LayersSourceFilterProtocol.self)
            return LayersFilterService(actionFilter: actionFilter, sourceFilter: sourceFilter)
        }

        // Elements
        register(ElementsSizeFilterProtocol.self) {
            ElementSizeFilterService()
        }

        register(ElementsColorFilterProtocol.self) {
            ElementsColorFilterService()
        }

        register(ElementsPositionFilterProtocol.self) {
            ElementsPositionFilterService()
        }

        register(ElementsFilterProtocol.self) {
            let sizeFilter = DI.injectOrFail(ElementsSizeFilterProtocol.self)
            let colorFilter = DI.injectOrFail(ElementsColorFilterProtocol.self)
            let positionFilter = DI.injectOrFail(ElementsPositionFilterProtocol.self)
            return ElementsFilterService(sizeFilter: sizeFilter, positionFilter: positionFilter, colorFilter: colorFilter)
        }

        // Content
        register(ContentPositionFilterProtocol.self) {
            ContentPositionFilterService()
        }

        register(VariantFilterProtocol.self) {
            let layersFilter = DI.injectOrFail(LayersFilterProtocol.self)
            let elementsFilter = DI.injectOrFail(ElementsFilterProtocol.self)
            let contentPositionFilter = DI.injectOrFail(ContentPositionFilterProtocol.self)
            return VariantFilterService(layersFilter: layersFilter, elementsFilter: elementsFilter, contentPositionFilter: contentPositionFilter)
        }

        register(InappFilterProtocol.self, scope: .transient) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let variantsFilter = DI.injectOrFail(VariantFilterProtocol.self)
            let sdkVersionValidator = DI.injectOrFail(SDKVersionValidator.self)
            return InappsFilterService(persistenceStorage: persistenceStorage,
                                       variantsFilter: variantsFilter,
                                       sdkVersionValidator: sdkVersionValidator)
        }

        register(InappSessionManagerProtocol.self) {
            let coreManager = DI.injectOrFail(InAppCoreManagerProtocol.self)
            let configManager = DI.injectOrFail(InAppConfigurationManagerProtocol.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            let userVisitManager = DI.injectOrFail(UserVisitManagerProtocol.self)
            let inappTrackingService = DI.injectOrFail(InAppTrackingServiceProtocol.self)
            return InappSessionManager(inappCoreManager: coreManager, inappConfigManager: configManager, targetingChecker: targetingChecker, userVisitManager: userVisitManager, inappTrackingService: inappTrackingService)
        }
        
        register(InappShowFailureManagerProtocol.self) {
            let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
            let featureToggleManager = DI.injectOrFail(FeatureToggleManager.self)
            return InappShowFailureManager(
                databaseRepository: databaseRepository,
                featureToggleManager: featureToggleManager
            )
        }

        register(WebViewContentCacheProtocol.self) {
            WebViewContentCache()
        }

        register(WebViewContentPreloaderProtocol.self) {
            let cache = DI.injectOrFail(WebViewContentCacheProtocol.self)
            return WebViewContentPreloader(cache: cache)
        }

        register(PrerenderedWebViewHolderProtocol.self) {
            let preloader = DI.injectOrFail(WebViewContentPreloaderProtocol.self)
            return PrerenderedWebViewHolder(preloader: preloader)
        }

        return self
    }

    func registerInappPresentation() -> Self {
        register(InAppMessagesTracker.self) {
            let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
            return InAppMessagesTracker(databaseRepository: databaseRepository)
        }

        register(PresentationDisplayUseCase.self) {
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)
            return PresentationDisplayUseCase(tracker: tracker)
        }

        register(InAppPresentationManagerProtocol.self) {
            let displayUseCase = DI.injectOrFail(PresentationDisplayUseCase.self)
            return InAppPresentationManager(displayUseCase: displayUseCase)
        }
        
        register(InAppPresentationValidatorProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppPresentationValidator(persistenceStorage: persistenceStorage)
        }
        
        register(InAppTrackingServiceProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppTrackingService(persistenceStorage: persistenceStorage)
        }
        
        register(InappScheduleManagerProtocol.self) {
            let presentationManager = DI.injectOrFail(InAppPresentationManagerProtocol.self)
            let presentationValidator = DI.injectOrFail(InAppPresentationValidatorProtocol.self)
            let inappTrackingService = DI.injectOrFail(InAppTrackingServiceProtocol.self)
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)
            let failureManager = DI.injectOrFail(InappShowFailureManagerProtocol.self)
            
            return InappScheduleManager(
                presentationManager: presentationManager,
                presentationValidator: presentationValidator,
                trackingService: inappTrackingService,
                tracker: tracker,
                failureManager: failureManager
            )
        }

        return self
    }
}
