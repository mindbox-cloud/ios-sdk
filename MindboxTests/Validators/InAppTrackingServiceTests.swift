//
//  InAppTrackingServiceTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 03.06.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InAppTrackingServiceTests: XCTestCase {
    
    private var trackingService: InAppTrackingService!
    private var persistenceStorage: PersistenceStorage!
    
    override func setUp() {
        super.setUp()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        trackingService = InAppTrackingService(persistenceStorage: persistenceStorage)
        SessionTemporaryStorage.shared.erase()
        persistenceStorage.shownInappsShowDatesDictionary = [:]
    }
    
    override func tearDown() {
        trackingService = nil
        persistenceStorage = nil
        SessionTemporaryStorage.shared.erase()
        super.tearDown()
    }
    
    func test_trackInAppShown_updatesSessionAndPersistenceStorage() {
        // Given
        let inAppId = "test-inapp-id"
        let now = Date()
        
        // When
        trackingService.trackInAppShown(id: inAppId)
        
        // Then
        XCTAssertEqual(SessionTemporaryStorage.shared.sessionShownInApps, [inAppId])
        XCTAssertEqual(persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.count, 1)
        XCTAssertNotNil(persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.first)
        if let storedDate = persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.first {
            XCTAssertTrue(Calendar.current.isDate(storedDate, inSameDayAs: now))
        }
    }
    
    func test_trackInAppShown_multipleTimes_updatesDatesCorrectly() {
        // Given
        let inAppId = "test-inapp-id"
        let now = Date()
        
        // When
        trackingService.trackInAppShown(id: inAppId)
        trackingService.trackInAppShown(id: inAppId)
        trackingService.trackInAppShown(id: inAppId)
        
        // Then
        XCTAssertEqual(SessionTemporaryStorage.shared.sessionShownInApps, [inAppId, inAppId, inAppId])
        XCTAssertEqual(persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.count, 3)
        XCTAssertNotNil(persistenceStorage.shownInappsShowDatesDictionary?[inAppId])
        if let dates = persistenceStorage.shownInappsShowDatesDictionary?[inAppId] {
            for date in dates {
                XCTAssertTrue(Calendar.current.isDate(date, inSameDayAs: now))
            }
        }
    }
    
    func test_trackInAppShown_differentInApps_updatesCorrectly() {
        // Given
        let inAppId1 = "test-inapp-id-1"
        let inAppId2 = "test-inapp-id-2"
        let now = Date()
        
        // When
        trackingService.trackInAppShown(id: inAppId1)
        trackingService.trackInAppShown(id: inAppId2)
        
        // Then
        XCTAssertEqual(SessionTemporaryStorage.shared.sessionShownInApps, [inAppId1, inAppId2])
        XCTAssertEqual(persistenceStorage.shownInappsShowDatesDictionary?[inAppId1]?.count, 1)
        XCTAssertEqual(persistenceStorage.shownInappsShowDatesDictionary?[inAppId2]?.count, 1)
        
        XCTAssertNotNil(persistenceStorage.shownInappsShowDatesDictionary?[inAppId1]?.first)
        if let storedDate1 = persistenceStorage.shownInappsShowDatesDictionary?[inAppId1]?.first {
            XCTAssertTrue(Calendar.current.isDate(storedDate1, inSameDayAs: now))
        }
        
        XCTAssertNotNil(persistenceStorage.shownInappsShowDatesDictionary?[inAppId2]?.first)
        if let storedDate2 = persistenceStorage.shownInappsShowDatesDictionary?[inAppId2]?.first {
            XCTAssertTrue(Calendar.current.isDate(storedDate2, inSameDayAs: now))
        }
    }
    
    func test_trackInAppShown_cleanupOldDates() {
        // Given
        let inAppId = "test-inapp-id"
        let calendar = Calendar.current
        let now = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        
        // When
        persistenceStorage.shownInappsShowDatesDictionary = [
            inAppId: [threeDaysAgo, twoDaysAgo, yesterday, now]
        ]
        trackingService.trackInAppShown(id: inAppId)
        
        // Then
        XCTAssertEqual(persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.count, 3)
        XCTAssertNotNil(persistenceStorage.shownInappsShowDatesDictionary?[inAppId])
        if let dates = persistenceStorage.shownInappsShowDatesDictionary?[inAppId] {
            XCTAssertFalse(dates.contains { date in
                Calendar.current.isDate(date, inSameDayAs: threeDaysAgo)
            })
            
            for date in dates {
                let isInRange = Calendar.current.isDate(date, inSameDayAs: twoDaysAgo) ||
                               Calendar.current.isDate(date, inSameDayAs: yesterday) ||
                               Calendar.current.isDate(date, inSameDayAs: now)
                XCTAssertTrue(isInRange, "Date \(date) is not in the expected range")
            }
        }
    }
    
    func test_trackInAppShown_withCustomCalendar() {
        // Given
        let inAppId = "test-inapp-id"
        let calendar = Calendar(identifier: .gregorian)
        let customTrackingService = InAppTrackingService(persistenceStorage: persistenceStorage, calendar: calendar)
        let now = Date()
        
        // When
        customTrackingService.trackInAppShown(id: inAppId)
        
        // Then
        XCTAssertEqual(SessionTemporaryStorage.shared.sessionShownInApps, [inAppId])
        XCTAssertEqual(persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.count, 1)
        XCTAssertNotNil(persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.first)
        if let storedDate = persistenceStorage.shownInappsShowDatesDictionary?[inAppId]?.first {
            XCTAssertTrue(calendar.isDate(storedDate, inSameDayAs: now))
        }
    }
} 
