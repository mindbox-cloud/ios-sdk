//
//  InappScheduleManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 03.07.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

protocol InappScheduleManagerProtocol {
    var delegate: InAppMessagesDelegate? { get set }
    func scheduleInApp(_ inAppFormData: InAppFormData)
    func cancelAllScheduledInApps()
}

final class InappScheduleManager: InappScheduleManagerProtocol {
    
    let presentationManager: InAppPresentationManagerProtocol
    
    init(presentationManager: InAppPresentationManagerProtocol) {
        self.presentationManager = presentationManager
    }
    
    weak var delegate: InAppMessagesDelegate?
    
    func scheduleInApp(_ inAppFormData: InAppFormData) {
        // TODO: - Add some logic here
    }
    
    func cancelAllScheduledInApps() {
        // TODO: - Add some logic here
    }
}

extension InappScheduleManager {
    
}
