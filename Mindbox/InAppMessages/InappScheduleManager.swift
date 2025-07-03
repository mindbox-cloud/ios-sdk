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
    
    let queue = DispatchQueue(label: "com.Mindbox.delayedInAppManager", qos: .userInitiated)
    var inappsByPresentationTime: [TimeInterval: [ScheduledInapp]] = [:]
    
    init(presentationManager: InAppPresentationManagerProtocol) {
        self.presentationManager = presentationManager
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
            self?.tryPresentFromDateGroup(presentationTime)
        }
        
        let scheduledInapp = ScheduledInapp(inapp: inapp, workItem: workItem)
        
        queue.async {
            self.inappsByPresentationTime[presentationTime, default: []].append(scheduledInapp)
            Logger.common(message: "[InappScheduleManager] Scheduled \(inapp.inAppId) at \(presentationTime) priority=\(inapp.isPriority)")
        }
        
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

}

extension InappScheduleManager {
    private func getDelay(_ time: String?) -> TimeInterval {
        let delayTimeStr = time
        let delayMilisec = (try? delayTimeStr?.parseTimeSpanToMillis()) ?? 0
        return TimeInterval(delayMilisec)
        // TODO: - Check later if there any difference between parse in milis / seconds
    }
}

