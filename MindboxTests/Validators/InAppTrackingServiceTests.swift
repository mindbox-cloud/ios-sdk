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
    private var history = InappShowHistory()
    
    override func setUp() {
        super.setUp()
        trackingService = InAppTrackingService()
        history = InappShowHistory(shownDatesByInApp: [:])
    }
    
    override func tearDown() {
        trackingService = nil
        super.tearDown()
    }
    
    func test_trackInAppShown_updatesTheHistory() {
        // Given
        let inAppId = "test-inapp-id"
        let now = Date()
        
        // When
        trackingService.trackInAppShown(id: inAppId, in: &history)
        
        // Then
        XCTAssertEqual(history.shownDatesByInApp?[inAppId]?.count, 1)
        XCTAssertNotNil(history.shownDatesByInApp?[inAppId]?.first)
        if let storedDate = history.shownDatesByInApp?[inAppId]?.first {
            XCTAssertTrue(Calendar.current.isDate(storedDate, inSameDayAs: now))
        }
    }
    
    func test_trackInAppShown_multipleTimes_updatesDatesCorrectly() {
        // Given
        let inAppId = "test-inapp-id"
        let now = Date()
        
        // When
        trackingService.trackInAppShown(id: inAppId, in: &history)
        trackingService.trackInAppShown(id: inAppId, in: &history)
        trackingService.trackInAppShown(id: inAppId, in: &history)
        
        // Then
        XCTAssertEqual(history.shownDatesByInApp?[inAppId]?.count, 3)
        XCTAssertNotNil(history.shownDatesByInApp?[inAppId])
        if let dates = history.shownDatesByInApp?[inAppId] {
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
        trackingService.trackInAppShown(id: inAppId1, in: &history)
        trackingService.trackInAppShown(id: inAppId2, in: &history)
        
        // Then
        XCTAssertEqual(history.shownDatesByInApp?[inAppId1]?.count, 1)
        XCTAssertEqual(history.shownDatesByInApp?[inAppId2]?.count, 1)
        
        XCTAssertNotNil(history.shownDatesByInApp?[inAppId1]?.first)
        if let storedDate1 = history.shownDatesByInApp?[inAppId1]?.first {
            XCTAssertTrue(Calendar.current.isDate(storedDate1, inSameDayAs: now))
        }
        
        XCTAssertNotNil(history.shownDatesByInApp?[inAppId2]?.first)
        if let storedDate2 = history.shownDatesByInApp?[inAppId2]?.first {
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
        history.shownDatesByInApp = [
            inAppId: [threeDaysAgo, twoDaysAgo, yesterday, now]
        ]
        trackingService.trackInAppShown(id: inAppId, in: &history)
        
        // Then
        XCTAssertEqual(history.shownDatesByInApp?[inAppId]?.count, 3)
        XCTAssertNotNil(history.shownDatesByInApp?[inAppId])
        if let dates = history.shownDatesByInApp?[inAppId] {
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
        let customTrackingService = InAppTrackingService(calendar: calendar)
        let now = Date()
        
        // When
        customTrackingService.trackInAppShown(id: inAppId, in: &history)
        
        // Then
        XCTAssertEqual(history.shownDatesByInApp?[inAppId]?.count, 1)
        XCTAssertNotNil(history.shownDatesByInApp?[inAppId]?.first)
        if let storedDate = history.shownDatesByInApp?[inAppId]?.first {
            XCTAssertTrue(calendar.isDate(storedDate, inSameDayAs: now))
        }
    }
} 
