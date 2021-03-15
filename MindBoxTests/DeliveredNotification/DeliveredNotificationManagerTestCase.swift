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
    var persistenceStorage: PersistenceStorage!
    
    let mockUtility = MockUtility()
    
    override func setUp() {
        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        DIManager.shared.container.registerInContainer { _ -> DataBaseLoader in
            return try! MockDataBaseLoader()
        }
        databaseRepository = DIManager.shared.container.resolve()
        if guaranteedDeliveryManager == nil {
            guaranteedDeliveryManager = GuaranteedDeliveryManager()
        }
        DIManager.shared.container.registerInContainer { _ -> UNAuthorizationStatusProviding in
            return MockUNAuthorizationStatusProvider(status: .authorized)
        }
        persistenceStorage = DIManager.shared.container.resolve()
        persistenceStorage.reset()
        try! databaseRepository.erase()
    }
    
    func testTrackOnlySaveIfConfigurationNotSet() {
        let manager = DeliveredNotificationManager()
        let content = UNMutableNotificationContent()
        let uniqueKey = mockUtility.randomString()
        let id = UUID().uuidString
        content.userInfo = ["uniqueKey": uniqueKey]
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        do {
            let eventsCount = try databaseRepository.countEvents()
            XCTAssertTrue(eventsCount == 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let isTracked = try manager.track(request: request)
            XCTAssertTrue(isTracked)
            do {
                let eventsCount = try databaseRepository.countEvents()
                XCTAssertTrue(eventsCount == 1)
            } catch {
                XCTFail(error.localizedDescription)
            }
            do {
                guard let event = try databaseRepository.query(fetchLimit: 1).first else {
                    XCTFail("Could not query event after store in db")
                    return
                }
                guard let body = BodyDecoder<PushDelivered>(decodable: event.body)?.body else {
                    XCTFail("Could not decode body form event: \(event)")
                    return
                }
                XCTAssertTrue(uniqueKey == body.uniqKey)
            } catch {
                XCTFail(error.localizedDescription)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testNotTrackIfNotificationIsNotMindBox() {
        let manager = DeliveredNotificationManager()
        let content = UNMutableNotificationContent()
        let uniqueKey = mockUtility.randomString()
        let id = mockUtility.randomString()
        content.userInfo = ["NonMindBoxKey": uniqueKey]
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        do {
            let eventsCount = try databaseRepository.countEvents()
            XCTAssertTrue(eventsCount == 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            let isTracked = try manager.track(request: request)
            XCTAssertFalse(isTracked)
            do {
                let eventsCount = try databaseRepository.countEvents()
                XCTAssertTrue(eventsCount == 0)
            } catch {
                XCTFail(error.localizedDescription)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

}
