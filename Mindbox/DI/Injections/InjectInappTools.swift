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

        return self
    }

    func registerInappPresentation() -> Self {
        register(InAppMessagesTracker.self) {
            let databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
            return InAppMessagesTracker(databaseRepository: databaseRepository)
        }

        register(PresentationDisplayUseCase.self) {
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)
            return PresentationDisplayUseCase(tracker: tracker)
        }

        register(UseCaseFactoryProtocol.self) {
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)
            return ActionUseCaseFactory(tracker: tracker)
        }

        register(InAppActionHandlerProtocol.self) {
            let actionUseCaseFactory = DI.injectOrFail(UseCaseFactoryProtocol.self)
            return InAppActionHandler(actionUseCaseFactory: actionUseCaseFactory)
        }

        register(InAppPresentationManagerProtocol.self) {
            let actionHandler = DI.injectOrFail(InAppActionHandlerProtocol.self)
            let displayUseCase = DI.injectOrFail(PresentationDisplayUseCase.self)
            return InAppPresentationManager(actionHandler: actionHandler, displayUseCase: displayUseCase)
        }
        
        register(InAppPresentationValidatorProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppPresentationValidator(persistenceStorage: persistenceStorage)
        }
        
        register(InAppTrackingServiceProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return InAppTrackingService(persistenceStorage: persistenceStorage)
        }

        return self
    }
}
