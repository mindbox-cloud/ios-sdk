//
//  NotificationService.swift
//  MindboxNotificationServiceExtension
//
//  Created by Дмитрий Ерофеев on 30.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UserNotifications
import MindboxNotifications

class NotificationService: UNNotificationServiceExtension {
    
    lazy var mindboxService = MindboxNotificationService()
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let userInfo = request.content.userInfo
        
        if mindboxService.isMindboxPush(userInfo: userInfo), let mindboxPushNotification = mindboxService.getMindboxPushData(userInfo: userInfo) {
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
    private func saveSwiftDataItem(_ mindboxPushNotification: MBPushNotification) async {
        let context = SwiftDataManager.shared.container.mainContext

        let push = PushNotification(title: mindboxPushNotification.aps?.alert?.title, 
                                    body: mindboxPushNotification.aps?.alert?.body,
                                    clickUrl: mindboxPushNotification.clickUrl,
                                    imageUrl: mindboxPushNotification.imageUrl,
                                    payload: mindboxPushNotification.payload,
                                    uniqueKey: mindboxPushNotification.uniqueKey)
        let newItem = Item(timestamp: Date(), pushNotification: push)
        
        context.insert(newItem)
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}
