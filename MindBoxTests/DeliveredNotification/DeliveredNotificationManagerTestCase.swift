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

    var databaseRepository: MBDatabaseRepository {
        container.databaseRepository
    }
    var persistenceStorage: PersistenceStorage {
        container.persistenceStorage
    }
    
    var container = try! TestDependencyProvider()
        
    override func setUp() {
        persistenceStorage.reset()
        try! databaseRepository.erase()
    }
    
    func testTrackOnlySaveIfConfigurationNotSet() {
        let manager = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository()
        )
        let content = UNMutableNotificationContent()
        let uniqueKey = UUID().uuidString
        let id = UUID().uuidString
        let aps = ["uniqueKey": uniqueKey]
        content.userInfo = ["aps": aps]
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
        let manager = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository()
        )
        let content = UNMutableNotificationContent()
        let uniqueKey = UUID().uuidString
        let id = UUID().uuidString
        let aps = ["NonMindBoxKey": uniqueKey]
        content.userInfo = ["aps": aps]
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
