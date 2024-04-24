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
    
    init(name: String, model: InappOperationJSONModel?) {
        self.name = name.lowercased()
        self.model = model
    }
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
        serialQueue: DispatchQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue")
    ) {
        self.configManager = configManager
        self.presentationManager = presentationManager
        self.persistenceStorage = persistenceStorage
        self.serialQueue = serialQueue
    }

    weak var delegate: InAppMessagesDelegate?

    private let configManager: InAppConfigurationManagerProtocol
    private let presentationManager: InAppPresentationManagerProtocol
    private let persistenceStorage: PersistenceStorage
    private var isConfigurationReady = false
    private let serialQueue: DispatchQueue
    private var unhandledEvents: [InAppMessageTriggerEvent] = []

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
            guard self.isConfigurationReady else {
                self.unhandledEvents.append(event)
                return
            }
            
            Logger.common(message: "Received event: \(event)", level: .debug, category: .inAppMessages)
            self.handleEvent(event)
        }
    }

    // MARK: - Private

    /// Core flow that decised to show in-app message based on incoming event
    private func handleEvent(_ event: InAppMessageTriggerEvent) {
        guard !SessionTemporaryStorage.shared.isPresentingInAppMessage else {
            return
        }
        
        onReceivedInAppResponse()
    }

    private func onReceivedInAppResponse() {
        guard let inapp = configManager.getInapp() else {
            Logger.common(message: "No in-app messages to show", level: .info, category: .inAppMessages)
            return
        }

        SessionTemporaryStorage.shared.isPresentingInAppMessage = true

        Logger.common(message: "In-app with id \(inapp.inAppId) is going to be shown", level: .debug, category: .inAppMessages)

        presentationManager.present(
            inAppFormData: inapp,
            onPresented: {
                self.serialQueue.async {
                    self.persistenceStorage.shownInappsDictionary?[inapp.inAppId] = Date()
                }
            },
            onTapAction: { [delegate] url, payload in
                delegate?.inAppMessageTapAction(id: inapp.inAppId, url: url, payload: payload)
            },
            onPresentationCompleted: { [delegate] in
                delegate?.inAppMessageDismissed(id: inapp.inAppId)
            },
            onError: { error in
                switch error {
                case .failedToLoadWindow:
                        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
                        Logger.common(message: "Failed to present window", level: .debug, category: .inAppMessages)
                default:
                    break
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
