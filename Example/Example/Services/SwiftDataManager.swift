//
//  SwiftDataManager.swift
//  Example
//
//  Created by Sergei Semko on 6/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import Mindbox
import SwiftData
import SwiftUI

public struct SwiftDataManager {
    public static let shared = SwiftDataManager()
    public var container: ModelContainer
    
    private var mockDataSaved: Bool {
        UserDefaults.standard.bool(forKey: "isMockDataSaved")
    }
    
    private init() {
        let schema = Schema([
            Item.self,
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    public func saveMockDataIfNeeded() {
        guard !mockDataSaved else {
            print("MockData already saved")
            return
        }
        Task {
            await saveMockData()
        }
        UserDefaults.standard.set(true, forKey: "isMockDataSaved")
    }
    
    @MainActor
    private func saveMockData() {
        let context = SwiftDataManager.shared.container.mainContext
        
        testNotifications.forEach { notification in
            guard let pushNotification = MBPushNotification(jsonString: notification) else {
                print("Failed to create MBPushNotification")
                return
            }
            let newItem = Item(timestamp: Date(), pushNotification: pushNotification)
            
            context.insert(newItem)
            
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

private extension SwiftDataManager {
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
