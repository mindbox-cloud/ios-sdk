//
//  InAppPresentationValidatorTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 26.05.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class InAppPresentationValidatorTests: XCTestCase {
    
    private var validator: InAppPresentationValidator!
    private var persistenceStorage: PersistenceStorage!
    
    override func setUp() {
        super.setUp()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        validator = InAppPresentationValidator(persistenceStorage: persistenceStorage)
        SessionTemporaryStorage.shared.erase()
    }
    
    override func tearDown() {
        validator = nil
        persistenceStorage = nil
        SessionTemporaryStorage.shared.erase()
        super.tearDown()
    }
    
    // MARK: - isNotPresentingAnotherInApp tests
    
    func test_isNotPresentingAnotherInApp_whenNotPresenting_returnsTrue() {
        XCTAssertTrue(validator.isNotPresentingAnotherInApp())
    }
    
    func test_isNotPresentingAnotherInApp_whenPresenting_returnsFalse() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        XCTAssertFalse(validator.isNotPresentingAnotherInApp())
    }
    
    // MARK: - isUnderSessionLimit tests
    
    func test_isUnderSessionLimit_whenNoSettings_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = nil
        XCTAssertTrue(validator.isUnderSessionLimit())
    }
    
    func test_isUnderSessionLimit_whenUnderLimit_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 3, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        XCTAssertTrue(validator.isUnderSessionLimit())
    }
    
    func test_isUnderSessionLimit_whenAtLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        XCTAssertFalse(validator.isUnderSessionLimit())
    }
    
    func test_isUnderSessionLimit_whenOverLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2", "3"]
        XCTAssertFalse(validator.isUnderSessionLimit())
    }
    
    func test_isUnderSessionLimit_whenLimitIsZero_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 0, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        XCTAssertTrue(validator.isUnderSessionLimit())
    }
    
    func test_isUnderSessionLimit_whenLimitIsNegative_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: -1, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        XCTAssertTrue(validator.isUnderSessionLimit())
    }
    
    // MARK: - isUnderDailyLimit tests
    
    func test_isUnderDailyLimit_whenNoSettings_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = nil
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenUnderLimit_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 5, minIntervalBetweenShows: nil)
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [Date()],
            "2": [Date()]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenAtLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [Date()],
            "2": [Date()]
        ]
        XCTAssertFalse(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenOverLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [Date()],
            "2": [Date()],
            "3": [Date()]
        ]
        XCTAssertFalse(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_oneInappShownMultipleTimes_whenOverLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let todayMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let todayAfternoon = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!
        let todayEvening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
        
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [yesterday, todayMorning, todayAfternoon, todayEvening]
        ]
        
        XCTAssertFalse(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenLimitIsZero_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 0, minIntervalBetweenShows: nil)
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [Date(timeIntervalSince1970: 0)],
            "2": [Date(timeIntervalSince1970: 0)]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenLimitIsNegative_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: -1, minIntervalBetweenShows: nil)
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [Date(timeIntervalSince1970: 0)],
            "2": [Date(timeIntervalSince1970: 0)]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenInappsFromDifferentDays_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [yesterday],
            "2": [yesterday],
            "3": [Date(timeIntervalSince1970: 0)]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenShownInappsShowDatesDictionaryIsNil_returnsTrue() {
        persistenceStorage.shownInappsShowDatesDictionary = nil
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenShownInappsShowDatesDictionaryIsEmpty_returnsTrue() {
        persistenceStorage.shownInappsShowDatesDictionary = [:]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenInappsFromFutureDate_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        persistenceStorage.shownInappsShowDatesDictionary = [
            "1": [tomorrow],
            "2": [tomorrow]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    // MARK: - canPresentInApp tests
    
    func test_canPresentInApp_whenAllChecksPass_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 3, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        XCTAssertTrue(validator.canPresentInApp())
    }
    
    func test_canPresentInApp_whenIsPresenting_returnsFalse() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        XCTAssertFalse(validator.canPresentInApp())
    }
    
    func test_canPresentInApp_whenSessionLimitReached_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        XCTAssertFalse(validator.canPresentInApp())
    }
} 
