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
    case start // All inapps by now is Start
    /// Any other event sent to SDK
    case applicationEvent(String)
}

protocol InAppCoreManagerProtocol: AnyObject {
    func start()
    func sendEvent(_ event: InAppMessageTriggerEvent)
    var delegate: InAppMessagesDelegate? { get set }
}

/// The class is an entry point for all in-app messages logic.
/// The main responsibility it to handle incoming events and decide whether to show in-app message
final class InAppCoreManager: InAppCoreManagerProtocol {

    init(
        configManager: InAppConfigurationManagerProtocol,
        segmentationChecker: InAppSegmentationCheckerProtocol,
        presentationManager: InAppPresentationManagerProtocol,
        persistenceStorage: PersistenceStorage,
        serialQueue: DispatchQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue")
    ) {
        self.configManager = configManager
        self.segmentationChecker = segmentationChecker
        self.presentationManager = presentationManager
        self.persistenceStorage = persistenceStorage
        self.serialQueue = serialQueue
    }

    weak var delegate: InAppMessagesDelegate?

    private let configManager: InAppConfigurationManagerProtocol
    private let segmentationChecker: InAppSegmentationCheckerProtocol
    private let presentationManager: InAppPresentationManagerProtocol
    private let persistenceStorage: PersistenceStorage
    private var isConfigurationReady = false
    private var isPresentingInAppMessage = false
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
        guard !isPresentingInAppMessage,
              var inAppRequest = configManager.buildInAppRequest(event: event) else { return }

        // Filter already shown inapps
        let alreadyShownInApps = Set(persistenceStorage.shownInAppsIds ?? [])
        inAppRequest.possibleInApps = inAppRequest.possibleInApps.filter {
            !alreadyShownInApps.contains($0.inAppId)
        }
//        #if DEBUG
//        if let inAppDebug = inAppRequest.possibleInApps.first {
//            onReceivedInAppResponse(InAppResponse(triggerEvent: event, inAppToShowId: inAppDebug.inAppId))
//        }
//        return
//        #endif

        guard !inAppRequest.possibleInApps.isEmpty else { return }

        // No need to check targenting if first inapp has no any taggeting
        if let firstInapp = inAppRequest.possibleInApps.first {
            onReceivedInAppResponse(InAppResponse(triggerEvent: event, inAppToShowId: firstInapp.inAppId))
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
        guard !isPresentingInAppMessage else { return }
        isPresentingInAppMessage = true

        presentationManager.present(
            inAppFormData: inAppFormData,
            onPresented: {
                self.serialQueue.async {
                    var newShownInAppsIds = self.persistenceStorage.shownInAppsIds ?? []
                    newShownInAppsIds.append(inAppResponse.inAppToShowId)
                    self.persistenceStorage.shownInAppsIds = newShownInAppsIds
                }
            },
            onTapAction: { [delegate] url, payload in
                delegate?.inAppMessageTapAction(id: inAppResponse.inAppToShowId, url: url, payload: payload)
            },
            onPresentationCompleted: { [delegate] in
                self.serialQueue.async { self.isPresentingInAppMessage = false }
                delegate?.inAppMessageDismissed(id: inAppResponse.inAppToShowId)
            },
            onError: { error in
                switch error {
                case .failedToLoadImages:
                    Log("Failed to download image for url: \(inAppFormData.imageUrl.absoluteString)")
                        .category(.inAppMessages).level(.debug).make()
                }
                self.serialQueue.async { self.isPresentingInAppMessage = false }
            }
        )
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
