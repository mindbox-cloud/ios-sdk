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
    let workItem: DispatchWorkItem
}

protocol InappScheduleManagerProtocol {
    var delegate: InAppMessagesDelegate? { get set }
    func scheduleInApp(_ inAppFormData: InAppFormData)
    func cancelAllScheduledInApps()
}

final class InappScheduleManager: InappScheduleManagerProtocol {
    
    let presentationManager: InAppPresentationManagerProtocol
    let presentationValidator: InAppPresentationValidatorProtocol
    
    let queue = DispatchQueue(label: "com.Mindbox.delayedInAppManager", qos: .userInitiated)
    var inappsByPresentationTime: [TimeInterval: [ScheduledInapp]] = [:]
    
    init(presentationManager: InAppPresentationManagerProtocol,
         presentationValidator: InAppPresentationValidatorProtocol) {
        self.presentationManager = presentationManager
        self.presentationValidator = presentationValidator
    }
    
    weak var delegate: InAppMessagesDelegate?
    
    func scheduleInApp(_ inapp: InAppFormData) {
        let delay = getDelay(inapp.delayTime)
        let presentationTime = Date().timeIntervalSince1970 + delay
        
        let workItem = DispatchWorkItem { [weak self] in
            // TODO: - Should i check other states?
            DispatchQueue.main.sync {
                    guard UIApplication.shared.applicationState == .active else { return }
                }
            self?.showEligibleInapp(presentationTime)
        }
        
        let scheduledInapp = ScheduledInapp(inapp: inapp, workItem: workItem)
        
        queue.async {
            self.inappsByPresentationTime[presentationTime, default: []].append(scheduledInapp)
            Logger.common(message: "[InappScheduleManager] Scheduled \(inapp.inAppId) at \(presentationTime) priority=\(inapp.isPriority)")
        }
        
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

internal extension InappScheduleManager {
    func showEligibleInapp(_ presentationTime: TimeInterval) {
        guard let scheduledInapps = inappsByPresentationTime[presentationTime] else {
            // TODO: - May be should add log here
            return
        }

        let sortedScheduledInapps = scheduledInapps.sorted {
            $0.inapp.isPriority && !$1.inapp.isPriority
        }
        
        for inapp in sortedScheduledInapps {
            if presentationValidator.canPresentInApp(isPriority: inapp.inapp.isPriority, frequency: inapp.inapp.frequency, id: inapp.inapp.inAppId) {
                inappsByPresentationTime.removeValue(forKey: presentationTime)
                presentInapp(inapp.inapp)
                break
            }
        }
    }
    
    func presentInapp(_ inapp: InAppFormData) {

    }
    
    func getDelay(_ time: String?) -> TimeInterval {
        let delayTimeStr = time
        let delayMilisec = (try? delayTimeStr?.parseTimeSpanToMillis()) ?? 0
        return TimeInterval(delayMilisec)
        // TODO: - Check later if there any difference between parse in milis / seconds
    }
}

