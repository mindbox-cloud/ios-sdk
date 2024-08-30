//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Дмитрий Ерофеев on 30.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UserNotifications
import MindboxNotifications
import Mindbox

class NotificationService: UNNotificationServiceExtension {
    
    lazy var mindboxService = MindboxNotificationService()
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        if let mindboxPushNotification = Mindbox.shared.getMindboxPushData(userInfo: request.content.userInfo) {
            Task {
                await saveSwiftDataItem(mindboxPushNotification)
            }
        }
        
        mindboxService.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        mindboxService.serviceExtensionTimeWillExpire()
    }
    
    @MainActor
    private func saveSwiftDataItem(_ pushNotification: MBPushNotification) async {
        let context = SwiftDataManager.shared.container.mainContext

        let newItem = Item(timestamp: Date(), pushNotification: pushNotification)
        
        context.insert(newItem)
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}
