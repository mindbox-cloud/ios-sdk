//
//  InAppCoreManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

/// Event that may trigger showing in-app message
enum InAppMessageTriggerEvent: Hashable {
    static func == (lhs: InAppMessageTriggerEvent, rhs: InAppMessageTriggerEvent) -> Bool {
        switch (lhs, rhs) {
        case (.start, .start):
            return true
        case let (.applicationEvent(lhs), .applicationEvent(rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
    
    /// Application start event. Fires after SDK configurated
    case start // All inapps by now is Start
    /// Any other event sent to SDK
    case applicationEvent(ApplicationEvent)
}

struct ApplicationEvent: Hashable, Equatable {
    let name: String
    let model: InappOperationJSONModel?
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
        presentationManager: InAppPresentationManagerProtocol,
        persistenceStorage: PersistenceStorage,
        serialQueue: DispatchQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue"),
        sessionStorage: SessionTemporaryStorage
    ) {
        self.configManager = configManager
        self.presentationManager = presentationManager
        self.persistenceStorage = persistenceStorage
        self.serialQueue = serialQueue
        self.sessionStorage = sessionStorage
    }

    weak var delegate: InAppMessagesDelegate?

    private let configManager: InAppConfigurationManagerProtocol
    private let presentationManager: InAppPresentationManagerProtocol
    private let persistenceStorage: PersistenceStorage
    private var isConfigurationReady = false
    private let serialQueue: DispatchQueue
    private var unhandledEvents: [InAppMessageTriggerEvent] = []
    private let sessionStorage: SessionTemporaryStorage

    /// This method called on app start.
    /// The config file will be loaded here or fetched from the cache.
    func start() {
        sendEvent(.start)
        configManager.delegate = self
        configManager.prepareConfiguration()
    }

    /// This method handles events and decides if in-app message should be shown
    func sendEvent(_ event: InAppMessageTriggerEvent) {
        if case .applicationEvent(let event) = event {
            isConfigurationReady = false
            configManager.recalculateInapps(with: event)
        }
        
        serialQueue.async {
            Logger.common(message: "Received event: \(event)", level: .debug, category: .inAppMessages)
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
        guard !sessionStorage.isPresentingInAppMessage,
              var inAppRequest = configManager.buildInAppRequest(event: event) else { return }

        // Filter already shown inapps
        let alreadyShownInApps = Set(persistenceStorage.shownInAppsIds ?? [])
        inAppRequest.possibleInApps = inAppRequest.possibleInApps.filter {
            !alreadyShownInApps.contains($0.inAppId)
        }
        
        Logger.common(message: "Shown in-apps ids: [\(alreadyShownInApps)]", level: .info, category: .inAppMessages)
//        #if DEBUG
//        if let inAppDebug = inAppRequest.possibleInApps.first {
//            onReceivedInAppResponse(InAppResponse(triggerEvent: event, inAppToShowId: inAppDebug.inAppId))
//        }
//        return
//        #endif

        guard !inAppRequest.possibleInApps.isEmpty else {
            Logger.common(message: "No inapps to show", level: .info, category: .inAppMessages)
            return
        }

        // No need to check targenting if first inapp has no any taggeting
        if let firstInapp = inAppRequest.possibleInApps.first {
            onReceivedInAppResponse(InAppResponse(triggerEvent: event, inAppToShowId: firstInapp.inAppId))
        }
    }

    private func onReceivedInAppResponse(_ inAppResponse: InAppResponse?) {
        guard let inAppResponse = inAppResponse,
              let inAppFormData = configManager.getInAppFormData(by: inAppResponse)
        else { return }
        guard !sessionStorage.isPresentingInAppMessage else { return }
        sessionStorage.isPresentingInAppMessage = true
        
        Logger.common(message: "In-app with id \(inAppResponse.inAppToShowId) is going to be shown", level: .debug, category: .inAppMessages)

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
                delegate?.inAppMessageDismissed(id: inAppResponse.inAppToShowId)
            },
            onError: { error in
                switch error {
                case .failedToLoadImages:
                    Logger.common(message: "Failed to download image for url: \(inAppFormData.imageUrl.absoluteString)", level: .debug, category: .inAppMessages)
                }
            }
        )
    }

    private func handleQueuedEvents() {
        Logger.common(message: "Start handling waiting events. Count: \(unhandledEvents.count)", level: .debug, category: .inAppMessages)
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
