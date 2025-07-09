//
//  InappFrequencyTests.swift
//  MindboxTests
//
//  Created by vailence on 19.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_unwrapping

class InappFrequencyTests: XCTestCase {

    var validator: InappFrequencyValidator!
    var persistenceStorage: PersistenceStorage!

    override func setUp() {
        super.setUp()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownDatesByInApp = [:]
        validator = InappFrequencyValidator(persistenceStorage: persistenceStorage)
    }

    override func tearDown() {
        validator = nil
        persistenceStorage = nil
        super.tearDown()
    }

    func test_once_lifetime_firstTime_shown() throws {
        let onceFrequency = OnceFrequency(kind: .lifetime)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_once_lifetime_shownBefore() throws {
        persistenceStorage.shownDatesByInApp = ["1": [Date()]]
        let onceFrequency = OnceFrequency(kind: .lifetime)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_once_session_firstTime() throws {
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_once_session_shownInCurrentSession() throws {
        SessionTemporaryStorage.shared.sessionShownInApps.append("1")
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_once_session_shownInPreviousSession() throws {
        persistenceStorage.shownDatesByInApp = ["1": [Date()]]
        SessionTemporaryStorage.shared.sessionShownInApps.removeAll()
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_once_session_multipleInapps() throws {
        SessionTemporaryStorage.shared.sessionShownInApps.append("1")
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "2"))
    }

    func test_once_session_clearSession() throws {
        SessionTemporaryStorage.shared.sessionShownInApps.append("1")
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
        
        SessionTemporaryStorage.shared.sessionShownInApps.removeAll()
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_seconds_firstTime() throws {
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_days_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .day, value: -2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_days_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .day, value: 0, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_days_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .day, value: 2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_hours_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .hour, value: -2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .hours, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_hours_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .hour, value: 0, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .hours, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_hours_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .hour, value: 2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .hours, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_minutes_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .minute, value: -2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .minutes, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_minutes_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .minute, value: 0, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .minutes, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_minutes_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .minute, value: 2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .minutes, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_seconds_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .second, value: -2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertTrue(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_seconds_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .second, value: 0, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_periodic_seconds_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .second, value: 2, to: Date())!
        persistenceStorage.shownDatesByInApp = ["1": [shownDate]]
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_frequency_is_zero() throws {
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 0)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    func test_nil_frequency() throws {
        XCTAssertFalse(validator.isValid(frequency: nil, id: "1"))
    }

    func test_unknown_frequency() throws {
        let inappFrequency: InappFrequency = .unknown
        XCTAssertFalse(validator.isValid(frequency: inappFrequency, id: "1"))
    }

    private func getConfig(name: String) throws -> ConfigResponse {
        let bundle = Bundle(for: InappFrequencyTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}
