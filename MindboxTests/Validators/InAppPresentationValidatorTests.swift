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
