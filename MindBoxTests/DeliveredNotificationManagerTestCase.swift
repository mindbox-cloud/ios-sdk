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
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        let configurationStorage: ConfigurationStorage = DIManager.shared.container.resolveOrDie()
        configurationStorage.setConfiguration(configuration)
        configurationStorage.set(uuid: "0593B5CC-1479-4E45-A7D3-F0E8F9B40898")
        if guaranteedDeliveryManager == nil {
            guaranteedDeliveryManager = GuaranteedDeliveryManager()
        }
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    func testTrack() {
        try! databaseRepository.erase()
        let manager = try! DeliveredNotificationManager(appGroup: "")
        let content = UNMutableNotificationContent()
        content.userInfo = ["uniqKey": "somekey"]
        let request = UNNotificationRequest(
            identifier: "1234",
            content: content,
            trigger: nil
        )
        do {
            try manager.track(request: request)
            XCTAssertTrue(databaseRepository.count == 1)
        } catch {
            XCTFail()
        }
    }

}
