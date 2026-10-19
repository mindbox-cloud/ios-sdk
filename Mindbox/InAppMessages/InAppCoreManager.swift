//
//  InAppCoreManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger

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

    case start
    case applicationEvent(ApplicationEvent)
    
    var applicationEvent: ApplicationEvent? {
        guard case let .applicationEvent(event) = self else { return nil }
        return event
    }
}

class ApplicationEvent: Hashable {
    let name: String
    let model: InappOperationJSONModel?

    init(name: String, model: InappOperationJSONModel?) {
        self.name = name.lowercased()
        self.model = model
    }

    static func == (lhs: ApplicationEvent, rhs: ApplicationEvent) -> Bool {
        return lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

protocol InAppCoreManagerProtocol: AnyObject {
    func start()
    func sendEvent(_ event: InAppMessageTriggerEvent)
    func discardEvents()
    var delegate: InAppMessagesDelegate? { get set }
}

final class InAppCoreManager: InAppCoreManagerProtocol {

    init(
        configManager: InAppConfigurationManagerProtocol,
        inappScheduler: InappScheduleManagerProtocol,
        serialQueue: DispatchQueue = DispatchQueue(label: "com.Mindbox.InAppCoreManager.eventsQueue")
    ) {
        self.configManager = configManager
        self.serialQueue = serialQueue
        self.inappScheduler = inappScheduler
    }

    weak var delegate: InAppMessagesDelegate?

    private let configManager: InAppConfigurationManagerProtocol
    private let inappScheduler: InappScheduleManagerProtocol
    private var isConfigurationReady = false
    private var isInAppManagerLaunched: Bool = false
    private let serialQueue: DispatchQueue
    private var unhandledEvents: [InAppMessageTriggerEvent] = []

    func start() {
        guard !isInAppManagerLaunched else {
            Logger.common(message: "Skip launching InAppManager because it is already launched", level: .info, category: .visit)
            return
        }

        sendEvent(.start)
        isInAppManagerLaunched = true
        configManager.delegate = self
        configManager.prepareConfiguration()
    }

    func sendEvent(_ event: InAppMessageTriggerEvent) {
        serialQueue.async {
            guard self.isConfigurationReady else {
                self.saveEvent(event)
                return
            }

            Logger.common(message: "Received event: \(event)", level: .debug, category: .inAppMessages)
            self.handleEvent(event)
        }
    }
    
    func discardEvents() {
        serialQueue.async {
            Logger.common(message: "[InappCoreManager] Discard expired events.")
            self.isConfigurationReady = false
            self.configManager.resetInappManager()
            self.unhandledEvents = []
        }
    }

    // MARK: - Private
    
    private func saveEvent(_ event: InAppMessageTriggerEvent) {
        switch event {
        case .start:
            self.unhandledEvents.insert(event, at: 0)
        case .applicationEvent:
            self.unhandledEvents.append(event)
        }
    }

    private func handleEvent(_ event: InAppMessageTriggerEvent,
                             _ completion: @escaping () -> Void = {}) {
        
        if case .applicationEvent(let customEvent) = event, !shouldHandleCustomOperation(customEvent.name) {
            Logger.common(message: "\(customEvent.name) not contained in customOperations or in Settings. Ignoring... ", category: .inAppMessages)
            completion()
            return
        }

        if let applicationEvent = event.applicationEvent {
            NotificationCenter.default.post(name: .inAppOperationOccurred, object: applicationEvent)
        }

        let triggerTimestamp = CACurrentMediaTime()

        self.configManager.handleInapps(event: event.applicationEvent) { inapp in
            let processingDuration = CACurrentMediaTime() - triggerTimestamp
            self.onReceivedInAppResponse(inapp: inapp, processingDuration: processingDuration) {
                completion()
            }
        }
    }
    
    private func shouldHandleCustomOperation(_ operationName: String) -> Bool {
        return SessionTemporaryStorage.shared.customOperations.contains(operationName)
        || SessionTemporaryStorage.shared.viewProductOperation?.contains(operationName) ?? false
        || SessionTemporaryStorage.shared.viewCategoryOperation?.contains(operationName) ?? false
    }

    private func onReceivedInAppResponse(inapp: InAppFormData?, processingDuration: TimeInterval, completion: @escaping () -> Void) {
        guard let inapp = inapp else {
            Logger.common(message: "No in-app messages to show", level: .info, category: .inAppMessages)
            completion()
            return
        }
        
        inappScheduler.scheduleInApp(inapp, processingDuration: processingDuration)
        completion()
    }

    private func handleQueuedEvents() {
        Logger.common(message: "Start handling waiting events. Count: \(unhandledEvents.count)", level: .debug, category: .inAppMessages)
        processNextEvent()
    }
    
    // handleEvent may complete on main or the config queue; unhandledEvents belongs to serialQueue.
    private func processNextEvent() {
        guard !unhandledEvents.isEmpty else { return }
        let event = unhandledEvents.removeFirst()
        handleEvent(event) {
            self.serialQueue.async {
                self.processNextEvent()
            }
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
