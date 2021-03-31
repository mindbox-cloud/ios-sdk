//
//  DeliveredNotificationManagerTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 20.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox
import UserNotifications

class DeliveredNotificationManagerTestCase: XCTestCase {

    var databaseRepository: MBDatabaseRepository {
        container.databaseRepository
    }
    var persistenceStorage: PersistenceStorage {
        container.persistenceStorage
    }
    
    var container = try! TestDependencyProvider()
    
    var manager: DeliveredNotificationManager!
        
    override func setUp() {
        persistenceStorage.reset()
        try! databaseRepository.erase()
        manager = DeliveredNotificationManager(
            persistenceStorage: container.persistenceStorage,
            databaseRepository: container.databaseRepository,
            eventRepository: container.instanceFactory.makeEventRepository()
        )
    }
    
    private func generateNotificationContent(
        isRootAPSKey: Bool,
        payload: @autoclosure () -> [AnyHashable: Any]
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let payload = payload()
        if isRootAPSKey {
            content.userInfo = ["aps": payload]
        } else {
            content.userInfo = payload
        }
        return UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
    }
    
    func testIsTrackNonAPSPayload() {
        let request = generateNotificationContent(
            isRootAPSKey: false,
            payload: [manager.mindBoxIdentifireKey: UUID().uuidString]
        )
        do {
            let isTracked = try manager.track(request: request)
            XCTAssertTrue(isTracked)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testIsTrackAPSPayload() {
        let request = generateNotificationContent(
            isRootAPSKey: true,
            payload: [manager.mindBoxIdentifireKey: UUID().uuidString]
        )
        do {
            let isTracked = try manager.track(request: request)
            XCTAssertTrue(isTracked)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testTrackOnlySaveIfConfigurationNotSet() {
        let uniqueKey = UUID().uuidString
        let request = generateNotificationContent(
            isRootAPSKey: true,
            payload: [manager.mindBoxIdentifireKey: uniqueKey]
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
    
    func testNotTrackIfNotificationIsNotMindbox() {
        let uniqueKey = UUID().uuidString
        let request = generateNotificationContent(isRootAPSKey: true, payload: [UUID().uuidString: uniqueKey])
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
