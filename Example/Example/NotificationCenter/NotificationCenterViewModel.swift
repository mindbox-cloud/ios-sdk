//
//  NotificationCenterViewModel.swift
//  Example
//
//  Created by Sergei Semko on 6/10/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Mindbox
import Observation

protocol NotificationCenterViewModelProtocol: AnyObject {
    var lastTappedNotification: PushNotification? { get }
    var errorMessage: String? { get }
    
    func sendOperationNCPushOpen(notification: PushNotification)
    func sendOperationNCOpen()
}

@Observable final class NotificationCenterViewModel: NotificationCenterViewModelProtocol {
    
    // MARK: - NotificationCenterViewModelProtocol
    var errorMessage: String?
    var lastTappedNotification: PushNotification?
    
    func sendOperationNCPushOpen(notification: PushNotification) {
        lastTappedNotification = notification
        
        /*Assuming payload of push notification has this structure:
         {
         "pushName":"<Push name>",
         "pushDate":"<Push date>"
         }*/
        guard let dateTime = notification.decodedPayload?.pushDate,
              let translateName = notification.decodedPayload?.pushName else {
            errorMessage = "Payload isn't valid for operation"
            print("Payload isn't valid for operation")
            return
        }
        
        let json = """
        {
            "data": {
                "customAction": {
                    "customFields": {
                        "mobPushSendDateTime": "\(dateTime)",
                        "mobPushTranslateName": "\(translateName)"
                    }
                }
            }
        }
        """
        
        let operationName = "mobileapp.NCPushOpen"
        
        Mindbox.shared.executeAsyncOperation(operationSystemName: operationName, json: json)
        
        errorMessage = nil
    }
    
    func sendOperationNCOpen() {
        let operationName = "mobileapp.NCOpen"

        Mindbox.shared.executeAsyncOperation(operationSystemName: operationName, json: "{}")
    }
    
    init() {
        SwiftDataManager.shared.saveMockDataIfNeeded()
    }
}
