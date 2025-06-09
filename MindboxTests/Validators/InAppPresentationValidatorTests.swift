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
        persistenceStorage.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenAtLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        persistenceStorage.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]
        XCTAssertFalse(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenOverLimit_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        persistenceStorage.shownDatesByInApp = [
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
        
        persistenceStorage.shownDatesByInApp = [
            "1": [yesterday, todayMorning, todayAfternoon, todayEvening]
        ]
        
        XCTAssertFalse(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenLimitIsZero_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 0, minIntervalBetweenShows: nil)
        persistenceStorage.shownDatesByInApp = [
            "1": [Date(timeIntervalSince1970: 0)],
            "2": [Date(timeIntervalSince1970: 0)]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenLimitIsNegative_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: -1, minIntervalBetweenShows: nil)
        persistenceStorage.shownDatesByInApp = [
            "1": [Date(timeIntervalSince1970: 0)],
            "2": [Date(timeIntervalSince1970: 0)]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenInappsFromDifferentDays_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        persistenceStorage.shownDatesByInApp = [
            "1": [yesterday],
            "2": [yesterday],
            "3": [Date(timeIntervalSince1970: 0)]
        ]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenshownDatesByInAppIsNil_returnsTrue() {
        persistenceStorage.shownDatesByInApp = nil
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenshownDatesByInAppIsEmpty_returnsTrue() {
        persistenceStorage.shownDatesByInApp = [:]
        XCTAssertTrue(validator.isUnderDailyLimit())
    }
    
    func test_isUnderDailyLimit_whenInappsFromFutureDate_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: 2, minIntervalBetweenShows: nil)
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        persistenceStorage.shownDatesByInApp = [
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
    
    // MARK: - hasElapsedMinimumIntervalBetweenInApps tests
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenMinIntervalNotSet_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: nil)
        persistenceStorage.lastShownInappDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenMinIntervalIsZero_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "00:00:00")
        persistenceStorage.lastShownInappDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenLastShowDateIsNil_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "00:05:00")
        persistenceStorage.lastShownInappDate = nil
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenIntervalNotElapsed_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "00:05:00")
        persistenceStorage.lastShownInappDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertFalse(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenIntervalElapsed_returnsTrue() {
        let minInterval = "00:00:01" // 1 секунда
        let timeElapsed = 2.0 // Прошло 2 секунды, что больше минимального интервала
        
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(
            maxInappsPerSession: nil,
            maxInappsPerDay: nil,
            minIntervalBetweenShows: minInterval
        )
        persistenceStorage.lastShownInappDate = Date().addingTimeInterval(-timeElapsed)
        
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_withComplexInterval_returnsCorrectly() {
        let minInterval = "01:30:00" // 1 час 30 минут
        let timeElapsed = 5400.0 // Прошло 1.5 часа (5400 секунд), что равно минимальному интервалу
        
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(
            maxInappsPerSession: nil,
            maxInappsPerDay: nil,
            minIntervalBetweenShows: minInterval
        )
        persistenceStorage.lastShownInappDate = Date().addingTimeInterval(-timeElapsed)
        
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_withInvalidIntervalFormat_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "invalid_format")
        persistenceStorage.lastShownInappDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenMinIntervalIsNegative_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "-00:05:00")
        persistenceStorage.lastShownInappDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
} 
