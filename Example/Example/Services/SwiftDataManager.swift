//
//  SwiftDataManager.swift
//  Example
//
//  Created by Sergei Semko on 6/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
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
        
        mockNotifications.forEach { notification in
            let newItem = Item(timestamp: Date(), pushNotification: notification)
            
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
    var mockNotifications: [PushNotification] {
        [
            PushNotification(
                title: "First notification title",
                body: "First notification body",
                clickUrl: "https://mindbox.ru/",
                imageUrl: "https://mobpush-images.mindbox.ru/Mpush-test/1a73ebaa-3e5f-49f4-ae6c-462c9b64d34c/307be696-77e6-4d83-b7eb-c94be85f7a03.png",
                payload: "{\"pushName\": \"<Push name>\", \"pushDate\": \"<Push date>\"}",
                uniqueKey: "Push unique key: 1"
            ),
            
            PushNotification(
                title: "Second notification title",
                body: "Second notification body",
                clickUrl: "https://mindbox.ru/",
                imageUrl: "https://mobpush-images.mindbox.ru/Mpush-test/1a73ebaa-3e5f-49f4-ae6c-462c9b64d34c/2397fea9-383d-49bf-a6a0-181a267faa94.png",
                payload: "{\"pushName\": \"<Push name>\", \"pushDate\": \"<Push date>\"}",
                uniqueKey: "Push unique key: 2"
            ),
            
            PushNotification(
                title: "Third notification title",
                body: "Third notification body",
                clickUrl: "https://mindbox.ru/",
                imageUrl: "https://mobpush-images.mindbox.ru/Mpush-test/1a73ebaa-3e5f-49f4-ae6c-462c9b64d34c/bd4250b1-a7ac-4b8a-b91b-481b3b5c565c.png",
                payload: "{\"pushName\": \"<Push name>\", \"pushDate\": \"<Push date>\"}",
                uniqueKey: "Push unique key: 3"
            ),
        ]
    }
}
