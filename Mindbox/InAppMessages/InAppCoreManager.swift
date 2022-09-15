//
//  InAppCoreManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Event that may trigger showing in-app message
enum InAppMessageTriggerEvent: Hashable {
    /// Application start event. Fires after SDK configurated
    case start
    /// Any other event sent to SDK
    case applicationEvent(String)
}

protocol InAppCoreManagerProtocol: AnyObject {
    func start()
    func sendEvent(_ event: InAppMessageTriggerEvent)
}

/// The class is an entry point for all in-app messages logic.
/// The main responsibility it to handle incoming events and decide whether to show in-app message
final class InAppCoreManager: InAppCoreManagerProtocol {

    init(
        configManager: InAppConfigurationManagerProtocol,
        segmentationChecker: InAppSegmentationCheckerProtocol,
        presentationManager: InAppPresentationManagerProtocol,
        serialQueue: DispatchQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue")
    ) {
        self.configManager = configManager
        self.segmentationChecker = segmentationChecker
        self.presentationManager = presentationManager
        self.serialQueue = serialQueue
    }

    private let configManager: InAppConfigurationManagerProtocol
    private let segmentationChecker: InAppSegmentationCheckerProtocol
    private let presentationManager: InAppPresentationManagerProtocol
    private var isConfigurationReady = false
    private let serialQueue: DispatchQueue
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

//        #if DEBUG
//        if let inAppDebug = inAppRequest.possibleInApps.first {
//            onReceivedInAppResponse(InAppResponse(triggerEvent: event, inAppToShowId: inAppDebug.inAppId))
//        }
//        return
//        #endif

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
              let inAppFormData = configManager.getInAppFormData(by: inAppResponse)
        else { return }

        presentationManager.present(inAppFormData: inAppFormData, onPresentationCompleted: { _ in })
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
