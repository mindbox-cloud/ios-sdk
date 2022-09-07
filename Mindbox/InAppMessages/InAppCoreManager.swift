//
//  InAppCoreManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// The class is an entry point for all in-app messages logic.
/// The main responsibility it to handle incoming events and decide whether to show in-app message
final class InAppCoreManager {

    init(
        configManager: InAppConfigurationManager,
        presentChecker: InAppPresentChecker,
        presentationManager: InAppPresentationManager,
        imagesStorage: InAppImagesStorage
    ) {
        self.configManager = configManager
        self.presentChecker = presentChecker
        self.presentationManager = presentationManager
        self.imagesStorage = imagesStorage
    }

    private let configManager: InAppConfigurationManager
    private let presentChecker: InAppPresentChecker
    private let presentationManager: InAppPresentationManager
    private let imagesStorage: InAppImagesStorage
    private var isConfigurationReady = false

    /// This method called on app start.
    /// The config file will be loaded here or fetched from the cache.
    func start() {
        configManager.prepareConfiguration {
            self.isConfigurationReady = $0
        }
    }

    /// This method handles events and decides if in-app message should be shown
    func handleEvent(event: String) {
        Log("Received event: \(event)")
            .category(.inAppMessages).level(.debug).make()
        // if config is not ready, store event in the queue and when config prepared — handle events from queue
        // if isConfigurationReady {} else {}

        configManager.buildInAppRequest(event: event) { inAppRequest in
            guard let inAppRequest = inAppRequest else { return }

            self.presentChecker.getInAppToPresent(request: inAppRequest) { inAppResponse in
                guard let inAppResponse = inAppResponse else { return }

                let inAppMessage = self.configManager.buildInAppMessage(inAppResponse: inAppResponse)
                self.buildInAppUIModel(inAppMessage, completion: { inAppUIModel in
                    guard let inAppUIModel = inAppUIModel else {
                        return
                    }

                    DispatchQueue.main.async {
                        self.presentationManager.present(inAppUIModel: inAppUIModel)
                    }
                })
            }
        }
    }

    private func buildInAppUIModel(_ inAppMessage: InAppMessage, completion: @escaping (InAppMessageUIModel?) -> Void) {
        imagesStorage.getImage(url: inAppMessage.imageUrl) { imageData in
            let uiModel = imageData.map(InAppMessageUIModel.init)
            completion(uiModel)
        }
    }
}
