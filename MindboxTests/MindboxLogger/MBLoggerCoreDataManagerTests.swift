//
//  MBLoggerCoreDataManagerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import XCTest
import MindboxLogger
@testable import Mindbox

final class MBLoggerCoreDataManagerTests: XCTestCase {
//    var manager: MBLoggerCoreDataManager!
//
//    override func setUp() {
//        super.setUp()
//        manager = MBLoggerCoreDataManager.shared
//    }
//
//    override func tearDown() {
//        do {
//            try manager.deleteAll()
//        } catch { }
//        manager = nil
//        super.tearDown()
//    }
//
//    func testCreate() throws {
//        let message = "Test message"
//        let timestamp = Date()
//        try manager.create(message: message, timestamp: timestamp)
//
//        let fetchResult = try manager.fetchPeriod(timestamp, timestamp)
//        XCTAssertEqual(fetchResult.count, 1)
//        XCTAssertEqual(fetchResult[0].message, message)
//        XCTAssertEqual(fetchResult[0].timestamp, timestamp)
//    }
//
//    func testFetchFirstLog() throws {
//        let message1 = "Test message 1"
//        let message2 = "Test message 2"
//        let message3 = "Test message 3"
//        let timestamp1 = Date().addingTimeInterval(-60)
//        let timestamp2 = Date().addingTimeInterval(-30)
//        let timestamp3 = Date()
//        try manager.create(message: message1, timestamp: timestamp1)
//        try manager.create(message: message2, timestamp: timestamp2)
//        try manager.create(message: message3, timestamp: timestamp3)
//
//        let fetchResult = try manager.getFirstLog()
//        XCTAssertNotNil(fetchResult)
//        XCTAssertEqual(fetchResult!.message, message1)
//        XCTAssertEqual(fetchResult!.timestamp, timestamp1)
//    }
//
//    func testFetchLastLog() throws {
//        let message1 = "Test message 1"
//        let message2 = "Test message 2"
//        let message3 = "Test message 3"
//        let timestamp1 = Date().addingTimeInterval(-60)
//        let timestamp2 = Date().addingTimeInterval(-30)
//        let timestamp3 = Date()
//        try manager.create(message: message1, timestamp: timestamp1)
//        try manager.create(message: message2, timestamp: timestamp2)
//        try manager.create(message: message3, timestamp: timestamp3)
//
//        let fetchResult = try manager.getLastLog()
//        XCTAssertEqual(fetchResult!.message, message3)
//        XCTAssertEqual(fetchResult!.timestamp, timestamp3)
//    }
//
//    func testFetchPeriod() throws {
//        let message1 = "Test message 1"
//        let message2 = "Test message 2"
//        let message3 = "Test message 3"
//        let timestamp1 = Date().addingTimeInterval(-60)
//        let timestamp2 = Date().addingTimeInterval(-30)
//        let timestamp3 = Date()
//        try manager.create(message: message1, timestamp: timestamp1)
//        try manager.create(message: message2, timestamp: timestamp2)
//        try manager.create(message: message3, timestamp: timestamp3)
//
//        let fetchResult = try manager.fetchPeriod(timestamp1, timestamp2)
//        XCTAssertEqual(fetchResult.count, 2)
//        XCTAssertEqual(fetchResult[0].message, message1)
//        XCTAssertEqual(fetchResult[0].timestamp, timestamp1)
//        XCTAssertEqual(fetchResult[1].message, message2)
//        XCTAssertEqual(fetchResult[1].timestamp, timestamp2)
//    }
//
//    func testDelete_10_percents() throws {
//        let expectation = XCTestExpectation(description: "Waiting for testDelete_10_percents to complete")
//        try manager.deleteAll()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
//            expectation.fulfill()
//        })
//        
//        wait(for: [expectation], timeout: 3)
//        
//        let message = "testDelete_10_percents"
//
//        let calendar = Calendar.current
//        var dateComponents = DateComponents()
//        dateComponents.year = 2023
//        dateComponents.month = 1
//        dateComponents.day = 2
//        dateComponents.hour = 12
//        dateComponents.minute = 0
//        dateComponents.second = 0
//        dateComponents.timeZone = TimeZone(abbreviation: "UTC")
//
//        let specificDate = calendar.date(from: dateComponents)!
//        
//        for _ in 0..<10 {
//            try manager.create(message: message, timestamp: specificDate)
//        }
//
//        let fetchResult = try manager.fetchPeriod(specificDate, specificDate)
//        XCTAssertEqual(fetchResult.count, 10)
//        try manager.delete()
//        
//        let fetchResultAfterDeletion = try manager.fetchPeriod(specificDate.addingTimeInterval(-60), specificDate)
//        fetchResultAfterDeletion.forEach {
//            XCTAssertEqual($0.message, "testDelete_10_percents")
//        }
//    }
}
