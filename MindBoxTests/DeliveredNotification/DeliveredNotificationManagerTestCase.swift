//
//  DeliveredNotificationManagerTestCase.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 20.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindBox
import UserNotifications

class DeliveredNotificationManagerTestCase: XCTestCase {

    var databaseRepository: MBDatabaseRepository!
    var guaranteedDeliveryManager: GuaranteedDeliveryManager!
    
    let mockUtility = MockUtility()
    
    override func setUp() {
        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        DIManager.shared.container.register { _ -> NetworkFetcher in
            MockNetworkFetcher()
        }
        DIManager.shared.container.registerInContainer { _ -> DataBaseLoader in
            return try! MockDataBaseLoader()
        }
        databaseRepository = DIManager.shared.container.resolve()
        if guaranteedDeliveryManager == nil {
            guaranteedDeliveryManager = GuaranteedDeliveryManager()
        }
    }
    
    func testTrack() {
        try! databaseRepository.erase()
        let manager = DeliveredNotificationManager()
        let content = UNMutableNotificationContent()
        let uniqueKey = mockUtility.randomString()
        let id = mockUtility.randomString()
        content.userInfo = ["uniqueKey": uniqueKey]
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        do {
            let isTracked = try manager.track(request: request)
            XCTAssertTrue(isTracked)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

}
