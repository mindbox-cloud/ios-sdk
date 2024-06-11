//
//  NotificationCenterViewModel.swift
//  Example
//
//  Created by Sergei Semko on 6/10/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Mindbox

protocol NotificationCenterViewModelProtocol: AnyObject {
    var notifications: [MBPushNotification] { get }
    var lastTappedNotification: MBPushNotification? { get }
    
    func sendOperationNCPushOpen(notification: MBPushNotification)
    func sendOperationNCOpen()
}

@Observable final class NotificationCenterViewModel: NotificationCenterViewModelProtocol {
    
    // MARK: - NotificationCenterViewModelProtocol
    
    var notifications: [MBPushNotification] = []
    var lastTappedNotification: MBPushNotification?
    
    func sendOperationNCPushOpen(notification: MBPushNotification) {
        print(notification.payload)
        print(notification.decodedPayload)
        guard let dateTime = notification.decodedPayload?.pushDate,
              let translateName = notification.decodedPayload?.pushName else {
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
        lastTappedNotification = notification
    }
    
    func sendOperationNCOpen() {
        let operationName = "mobileapp.NCOpen"

        Mindbox.shared.executeAsyncOperation(operationSystemName: operationName, json: "{}")
    }
    
    // MARK: - Initialization
    
    init() {
        notifications = testNotifications.compactMap {
            MBPushNotification(jsonString: $0)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewPushNotification(_:)),
            name: .MindboxPushNotificationExample, 
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: .MindboxPushNotificationExample,
            object: nil
        )
    }
    
    // MARK: - Private methods
    
    @objc
    private func handleNewPushNotification(_ notification: Notification) {
        if let pushData = notification.userInfo?["pushData"] as? MBPushNotification {
            addNotification(pushData)
        }
    }
    
    private func addNotification(_ notification: MBPushNotification) {
        notifications.append(notification)
    }
}

// MARK: - MockData for Notification Center

private extension NotificationCenterViewModel {
    var testNotifications: [String] {
        [
            """
            {
                "aps": {
                    "alert": {
                        "title": "First notification title",
                        "body": "First notification body"
                    },
                    "sound": "default",
                    "mutable-content": 1,
                    "content-available": 1
                },
                "uniqueKey": "Push unique key: 1",
                "imageUrl": "https://mobpush-images.mindbox.ru/Mpush-test/1a73ebaa-3e5f-49f4-ae6c-462c9b64d34c/307be696-77e6-4d83-b7eb-c94be85f7a03.png",
                "payload": "{\\"pushName\\": \\"<Push name>\\", \\"pushDate\\": \\"<Push date>\\"}",
                "buttons": [],
                "clickUrl": "https://mindbox.ru/"
            }
            """,
            
            """
            {
                "aps": {
                    "alert": {
                        "title": "Second notification title",
                        "body": "Second notification body"
                    },
                    "sound": "default",
                    "mutable-content": 1,
                    "content-available": 1
                },
                "uniqueKey": "Push unique key: 2",
                "imageUrl": "https://mobpush-images.mindbox.ru/Mpush-test/1a73ebaa-3e5f-49f4-ae6c-462c9b64d34c/2397fea9-383d-49bf-a6a0-181a267faa94.png",
                "payload": "{\\"pushName\\": \\"<Push name>\\", \\"pushDate\\": \\"<Push date>\\"}",
                "buttons": [],
                "clickUrl": "https://mindbox.ru/"
            }
            """,
            
            """
            {
                "aps": {
                    "alert": {
                        "title": "Third notification title",
                        "body": "Third notification body"
                    },
                    "sound": "default",
                    "mutable-content": 1,
                    "content-available": 1
                },
                "uniqueKey": "Push unique key: 3",
                "imageUrl": "https://mobpush-images.mindbox.ru/Mpush-test/1a73ebaa-3e5f-49f4-ae6c-462c9b64d34c/bd4250b1-a7ac-4b8a-b91b-481b3b5c565c.png",
                "payload": "{\\"pushName\\": \\"<Push name>\\", \\"pushDate\\": \\"<Push date>\\"}",
                "buttons": [],
                "clickUrl": "https://mindbox.ru/"
            }
            """
        ]
    }
}
