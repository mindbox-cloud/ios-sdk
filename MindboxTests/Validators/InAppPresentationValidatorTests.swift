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
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertTrue(validator.canPresentInApp(isPriority: false, frequency: inappFrequency, id: "3"))
    }
    
    func test_canPresentInApp_whenIsPresenting_returnsFalse() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertFalse(validator.canPresentInApp(isPriority: false, frequency: inappFrequency, id: "1"))
    }
    
    func test_canPresentInApp_whenSessionLimitReached_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertFalse(validator.canPresentInApp(isPriority: false, frequency: inappFrequency, id: "3"))
    }
    
    // MARK: - hasElapsedMinimumIntervalBetweenInApps tests
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenMinIntervalNotSet_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: nil)
        persistenceStorage.lastInappStateChangeDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenMinIntervalIsZero_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "00:00:00")
        persistenceStorage.lastInappStateChangeDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenLastShowDateIsNil_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "00:05:00")
        persistenceStorage.lastInappStateChangeDate = nil
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenIntervalNotElapsed_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "00:05:00")
        persistenceStorage.lastInappStateChangeDate = Date()
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
        persistenceStorage.lastInappStateChangeDate = Date().addingTimeInterval(-timeElapsed)
        
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
        persistenceStorage.lastInappStateChangeDate = Date().addingTimeInterval(-timeElapsed)
        
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_withInvalidIntervalFormat_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "invalid_format")
        persistenceStorage.lastInappStateChangeDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    func test_hasElapsedMinimumIntervalBetweenInApps_whenMinIntervalIsNegative_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: nil, maxInappsPerDay: nil, minIntervalBetweenShows: "-00:05:00")
        persistenceStorage.lastInappStateChangeDate = Date()
        let result = validator.hasElapsedMinimumIntervalBetweenInApps()
        XCTAssertTrue(result)
    }
    
    // MARK: - Priority in-app tests
    
    func test_canPresentInApp_whenIsPriorityAndNotPresenting_returnsTrue() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "1")
        XCTAssertTrue(result)
    }
    
    func test_canPresentInApp_whenIsPriorityAndPresenting_returnsFalse() {
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "1")
        XCTAssertFalse(result)
    }
    
    func test_canPresentInApp_whenIsPriorityAndSessionLimitReached_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 5, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "3")
        XCTAssertTrue(result)
    }
    
    func test_canPresentInApp_whenIsPriorityAndDailyLimitReached_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 5, maxInappsPerDay: 2, minIntervalBetweenShows: "00:00:00")
        SessionTemporaryStorage.shared.sessionShownInApps = []
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        persistenceStorage.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]
        
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "3")
        XCTAssertTrue(result)
    }
    
    func test_canPresentInApp_whenIsPriorityAndIntervalNotElapsed_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 5, maxInappsPerDay: 5, minIntervalBetweenShows: "00:05:00")
        SessionTemporaryStorage.shared.sessionShownInApps = []
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        persistenceStorage.lastInappStateChangeDate = Date() // Recent change
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "1")
        XCTAssertTrue(result)
    }
    
    func test_canPresentInApp_whenIsPriorityAndAllLimitsReached_returnsTrue() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 2, minIntervalBetweenShows: "00:05:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        SessionTemporaryStorage.shared.isPresentingInAppMessage = false
        persistenceStorage.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]
        persistenceStorage.lastInappStateChangeDate = Date()
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "3")
        XCTAssertTrue(result)
    }
    
    func test_canPresentInApp_whenIsPriorityAndAllLimitsReachedButPresenting_returnsFalse() {
        SessionTemporaryStorage.shared.inAppSettings = Settings.InAppSettings(maxInappsPerSession: 2, maxInappsPerDay: 2, minIntervalBetweenShows: "00:05:00")
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        SessionTemporaryStorage.shared.isPresentingInAppMessage = true
        persistenceStorage.shownDatesByInApp = [
            "1": [Date()],
            "2": [Date()]
        ]
        persistenceStorage.lastInappStateChangeDate = Date()
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: true, frequency: inappFrequency, id: "3")
        XCTAssertFalse(result)
    }
    
    // MARK: - Frequency validation tests
    
    func test_canPresentInApp_withNilFrequency_returnsFalse() {
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        let result = validator.canPresentInApp(isPriority: false, frequency: nil, id: "3")
        XCTAssertFalse(result)
    }
    
    func test_canPresentInApp_withUnknownFrequency_returnsFalse() {
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        let inappFrequency: InappFrequency = .unknown
        let result = validator.canPresentInApp(isPriority: false, frequency: inappFrequency, id: "3")
        XCTAssertFalse(result)
    }
    
    func test_canPresentInApp_withPeriodicFrequency_returnsTrue() {
        SessionTemporaryStorage.shared.sessionShownInApps = ["1", "2"]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        persistenceStorage.shownDatesByInApp = ["3": [Date(timeIntervalSince1970: 0)]]
        let result = validator.canPresentInApp(isPriority: false, frequency: inappFrequency, id: "3")
        XCTAssertTrue(result)
    }
    
    func test_canPresentInApp_withLifetimeFrequency_returnsTrue() {
        let onceFrequency = OnceFrequency(kind: .lifetime)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let result = validator.canPresentInApp(isPriority: false, frequency: inappFrequency, id: "3")
        XCTAssertTrue(result)
    }
    
    // MARK: - Validation order tests
    
    func test_canPresentInApp_validationOrderForPriorityInApp() {
        // Arrange
        let wrapper = InAppPresentationValidatorWrapper(persistenceStorage: persistenceStorage)
        
        // Act
        let result = wrapper.canPresentInApp(isPriority: true, frequency: .once(OnceFrequency(kind: .session)), id: "priority_inapp")
        
        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(wrapper.validationChecks, [
            .isNotPresentingAnotherInApp,
            .isValidFrequency
        ], "Priority in-app should only perform isNotPresentingAnotherInApp and isValidFrequency checks")
    }
    
    func test_canPresentInApp_validationOrderForRegularInApp() {
        let wrapper = InAppPresentationValidatorWrapper(persistenceStorage: persistenceStorage)
        
        let result = wrapper.canPresentInApp(isPriority: false, frequency: .once(OnceFrequency(kind: .session)), id: "regular_inapp")
        
        XCTAssertTrue(result)
        XCTAssertEqual(wrapper.validationChecks, [
            .isNotPresentingAnotherInApp,
            .isValidFrequency,
            .isUnderSessionLimit,
            .isUnderDailyLimit,
            .hasElapsedMinimumIntervalBetweenInApps
        ], "Regular in-app should perform all 5 validation checks in correct order")
    }
}

// MARK: - Wrapper for validation order testing

class InAppPresentationValidatorWrapper: InAppPresentationValidatorProtocol {
    
    enum ValidationCheckType: String, CaseIterable {
        case isNotPresentingAnotherInApp = "isNotPresentingAnotherInApp"
        case isValidFrequency = "isValidFrequency"
        case isUnderSessionLimit = "isUnderSessionLimit"
        case isUnderDailyLimit = "isUnderDailyLimit"
        case hasElapsedMinimumIntervalBetweenInApps = "hasElapsedMinimumIntervalBetweenInApps"
    }
    
    private let validator: InAppPresentationValidator
    var validationChecks: [ValidationCheckType] = []
    
    init(persistenceStorage: PersistenceStorage) {
        self.validator = InAppPresentationValidator(persistenceStorage: persistenceStorage)
    }
    
    func canPresentInApp(isPriority: Bool, frequency: InappFrequency?, id: String) -> Bool {
        validationChecks.removeAll()
        return trackValidationOrder(isPriority: isPriority, frequency: frequency, id: id)
    }
    
    private func trackValidationOrder(isPriority: Bool, frequency: InappFrequency?, id: String) -> Bool {
        let isNotPresenting = validator.isNotPresentingAnotherInApp()
        validationChecks.append(.isNotPresentingAnotherInApp)
        if !isNotPresenting {
            return false
        }
        
        let isValidFrequency = validator.isValidFrequency(frequency: frequency, id: id)
        validationChecks.append(.isValidFrequency)
        if !isValidFrequency {
            return false
        }
        
        if isPriority {
            return true
        }
        
        let isUnderSessionLimit = validator.isUnderSessionLimit()
        validationChecks.append(.isUnderSessionLimit)
        if !isUnderSessionLimit {
            return false
        }
        
        let isUnderDailyLimit = validator.isUnderDailyLimit()
        validationChecks.append(.isUnderDailyLimit)
        if !isUnderDailyLimit {
            return false
        }
        
        let hasElapsedInterval = validator.hasElapsedMinimumIntervalBetweenInApps()
        validationChecks.append(.hasElapsedMinimumIntervalBetweenInApps)
        if !hasElapsedInterval {
            return false
        }
        
        return true
    }
}
