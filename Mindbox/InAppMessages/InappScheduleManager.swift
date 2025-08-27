//
//  InappScheduleManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.07.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger
import UIKit

internal struct ScheduledInapp {
    let inapp: InAppFormData
    let timer: DispatchSourceTimer
}

protocol InappScheduleManagerProtocol {
    var delegate: InAppMessagesDelegate? { get set }
    func scheduleInApp(_ inAppFormData: InAppFormData)
}

final class InappScheduleManager: InappScheduleManagerProtocol {
    
    let presentationManager: InAppPresentationManagerProtocol
    let presentationValidator: InAppPresentationValidatorProtocol
    let trackingService: InAppTrackingServiceProtocol
    
    let queue = DispatchQueue(label: "com.Mindbox.delayedInAppManager", qos: .userInitiated)
    var inappsByPresentationTime: [TimeInterval: [ScheduledInapp]] = [:]
    
    init(presentationManager: InAppPresentationManagerProtocol,
         presentationValidator: InAppPresentationValidatorProtocol,
         trackingService: InAppTrackingServiceProtocol) {
        self.presentationManager = presentationManager
        self.presentationValidator = presentationValidator
        self.trackingService = trackingService
        addObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    weak var delegate: InAppMessagesDelegate?
    
    func scheduleInApp(_ inapp: InAppFormData) {
        let delay = getDelay(inapp.delayTime)
        let presentationTime = Date().addingTimeInterval(delay).timeIntervalSince1970
        
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer.schedule(deadline: .now() + delay, repeating: .never, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard UIApplication.shared.applicationState == .active else {
                    Logger.common(message: "[InappScheduleManager] Skipping presentation of \(inapp.inAppId) because app is not active")
                    return
                }
                
                self?.showEligibleInapp(presentationTime)
            }
        }
        
        let scheduledInapp = ScheduledInapp(inapp: inapp, timer: timer)
        
        queue.async {
            self.inappsByPresentationTime[presentationTime, default: []].append(scheduledInapp)
            timer.resume()
            Logger.common(message: "[InappScheduleManager] Scheduled \(inapp.inAppId) at \(presentationTime.asReadableDateTime) priority=\(inapp.isPriority)")
        }
    }
}

internal extension InappScheduleManager {
    func showEligibleInapp(_ presentationTime: TimeInterval) {
        queue.async {
            guard let scheduledInapps = self.inappsByPresentationTime[presentationTime], !scheduledInapps.isEmpty else {
                return
            }
            
            let sortedScheduledInapps = scheduledInapps.sorted {
                $0.inapp.isPriority && !$1.inapp.isPriority
            }
            
            if let firstInapp = sortedScheduledInapps.first,
                self.presentationValidator.canPresentInApp(isPriority: firstInapp.inapp.isPriority,
                                                           frequency: firstInapp.inapp.frequency,
                                                           id: firstInapp.inapp.inAppId) {
                self.presentInapp(firstInapp.inapp)
            }
            
            for scheduledInapp in scheduledInapps {
                scheduledInapp.timer.cancel()
            }
            
            self.inappsByPresentationTime.removeValue(forKey: presentationTime)
        }
    }
    
    func presentInapp(_ inapp: InAppFormData) {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        SessionTemporaryStorage.shared.lastInappClickedID = nil
        
        Logger.common(message: "[InappScheduleManager] Showing in-app \(inapp.inAppId)")
        
        presentationManager.present(
            inAppFormData: inapp,
            onPresented: {
                self.trackingService.trackInAppShown(id: inapp.inAppId)
                self.trackingService.saveInappStateChange()
            },
            onTapAction: { [delegate] url, payload in
                delegate?.inAppMessageTapAction(
                    id: inapp.inAppId,
                    url: url,
                    payload: payload
                )
            },
            onPresentationCompleted: { [delegate] in
                SessionTemporaryStorage.shared.isPresentingInAppMessage = false
                delegate?.inAppMessageDismissed(id: inapp.inAppId)
                self.trackingService.saveInappStateChange()
            },
            onError: { error in
                if case .failedToLoadWindow = error {
                    SessionTemporaryStorage.shared.isPresentingInAppMessage = false
                    Logger.common(
                        message: "[InappScheduleManager] Failed to show window",
                        level: .debug, category: .inAppMessages
                    )
                }
            }
        )
    }
    
    func getDelay(_ time: String?) -> TimeInterval {
        let delayTimeStr = time
        let delayMilis = (try? delayTimeStr?.parseTimeSpanToMillis()) ?? 0
        return TimeInterval(delayMilis) / 1000
    }
    
    func addObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.checkExpiredInapps()
        }
    }
    
    func checkExpiredInapps() {
        queue.async {
            guard SessionTemporaryStorage.shared.isInitializationCalled else { return }
            
            if let configExpirationTime = SessionTemporaryStorage.shared.configSessionExpirationTime {
                if configExpirationTime < Date() {
                    
                    for scheduledInapps in self.inappsByPresentationTime.values {
                        for scheduledInapp in scheduledInapps {
                            scheduledInapp.timer.cancel()
                        }
                    }
                    
                    self.inappsByPresentationTime = [:]
                    Logger.common(message: "[InappScheduleManager] Session expired, canceling all scheduled in-app messages", level: .debug, category: .inAppMessages)
                    return
                }
            }
            
            let now = Date().timeIntervalSince1970
            let expiredInapps = self.inappsByPresentationTime.keys.filter { $0 <= now }
            if let earliestInapp = expiredInapps.min() {
                self.showEligibleInapp(earliestInapp)
                
                for expiredInapp in expiredInapps where expiredInapp != earliestInapp {
                    if let scheduledInapps = self.inappsByPresentationTime[expiredInapp] {
                        for scheduledInapp in scheduledInapps {
                            scheduledInapp.timer.cancel()
                        }
                    }
                    self.inappsByPresentationTime.removeValue(forKey: expiredInapp)
                }
            }
        }
    }
}
