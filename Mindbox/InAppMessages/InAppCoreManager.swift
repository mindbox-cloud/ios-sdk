//
//  InAppCoreManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

enum InAppMessageTriggerEvent {
    case start
    case applicationEvent(String)

    var eventName: String {
        switch self {
        case .start:
            return "start"
        case let .applicationEvent(name):
            return name
        }
    }
}

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
    private var eventsQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue")
    private var unhandledEvents: [InAppMessageTriggerEvent] = []

    /// This method called on app start.
    /// The config file will be loaded here or fetched from the cache.
    func start() {
        configManager.delegate = self
        configManager.prepareConfiguration()
        handleEvent(.start)
    }

    /// This method handles events and decides if in-app message should be shown
    func sendEvent(_ event: InAppMessageTriggerEvent) {
        eventsQueue.async {
            guard self.isConfigurationReady else {
                self.unhandledEvents.append(event)
                return
            }
            self.handleEvent(event)
        }
    }

    // MARK: - Private

    /// Core flow that decised to show in-app message based on incoming event
    private func handleEvent(_ event: InAppMessageTriggerEvent) {
        Log("Received event: \(event)")
            .category(.inAppMessages).level(.debug).make()

        guard let inAppRequest = configManager.buildInAppRequest(event: event) else { return }

        presentChecker.getInAppToPresent(request: inAppRequest) { inAppResponse in
            guard let inAppResponse = inAppResponse,
                  let inAppMessage = self.configManager.buildInAppMessage(inAppResponse: inAppResponse)
            else { return }

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

    private func handleQueuedEvents() {
        Log("Start handling waiting events. Count: \(unhandledEvents.count)")
            .category(.inAppMessages).level(.debug).make()
        while unhandledEvents.count > 0 {
            let event = unhandledEvents.removeFirst()
            handleEvent(event)
        }
    }

    private func buildInAppUIModel(_ inAppMessage: InAppMessage, completion: @escaping (InAppMessageUIModel?) -> Void) {
        imagesStorage.getImage(url: inAppMessage.imageUrl) { imageData in
            let uiModel = imageData.map(InAppMessageUIModel.init)
            completion(uiModel)
        }
    }
}

extension InAppCoreManager: InAppConfigurationDelegate {
    func didPreparedConfiguration() {
        eventsQueue.async {
            self.isConfigurationReady = true
            self.handleQueuedEvents()
        }
    }
}
