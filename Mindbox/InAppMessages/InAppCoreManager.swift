//
//  InAppCoreManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

enum InAppMessageTriggerEvent: Hashable {
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
        presentChecker: InAppSegmentationChecker,
        presentationManager: InAppPresentationManager,
        imagesStorage: InAppImagesStorage
    ) {
        self.configManager = configManager
        self.segmentationChecker = presentChecker
        self.presentationManager = presentationManager
        self.imagesStorage = imagesStorage
    }

    private let configManager: InAppConfigurationManager
    private let segmentationChecker: InAppSegmentationChecker
    private let presentationManager: InAppPresentationManager
    private let imagesStorage: InAppImagesStorage
    private var isConfigurationReady = false
    private var serialQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue")
    private var unhandledEvents: [InAppMessageTriggerEvent] = []

    /// This method called on app start.
    /// The config file will be loaded here or fetched from the cache.
    func start() {
        configManager.delegate = self
        configManager.prepareConfiguration()
        sendEvent(.start)
    }

    /// This method handles events and decides if in-app message should be shown
    func sendEvent(_ event: InAppMessageTriggerEvent) {
        serialQueue.async {
            Log("Received event: \(event)")
                .category(.inAppMessages).level(.debug).make()

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
        guard let inAppRequest = configManager.buildInAppRequest(event: event) else { return }

        if let firstInAppWithoutTargeting = inAppRequest.possibleInApps.first(where: { $0.targeting == nil }) {
            onReceivedInAppResponse(InAppResponse(triggerEvent: event, inAppToShowId: firstInAppWithoutTargeting.inAppId))
        } else {
            segmentationChecker.getInAppToPresent(request: inAppRequest, completionQueue: serialQueue) { inAppResponse in
                self.onReceivedInAppResponse(inAppResponse)
            }
        }
    }

    private func onReceivedInAppResponse(_ inAppResponse: InAppResponse?) {
        guard let inAppResponse = inAppResponse,
              let inAppMessage = configManager.getInAppFormData(for: inAppResponse.triggerEvent, inAppId: inAppResponse.inAppToShowId)
        else { return }

        imagesStorage.getImage(url: inAppMessage.imageUrl, completionQueue: .main) { imageData in
            guard let inAppUIModel = imageData.map(InAppMessageUIModel.init) else {
                return
            }
            self.presentationManager.present(inAppUIModel: inAppUIModel)
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
}

extension InAppCoreManager: InAppConfigurationDelegate {
    func didPreparedConfiguration() {
        serialQueue.async {
            self.isConfigurationReady = true
            self.handleQueuedEvents()
        }
    }
}
