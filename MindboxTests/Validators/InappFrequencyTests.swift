//
//  InappFrequencyTests.swift
//  MindboxTests
//
//  Created by vailence on 19.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class InappFrequencyTests: XCTestCase {

    var container: DependencyContainer!
    var validator: InappFrequencyValidator!
    var persistenceStorage: PersistenceStorage!

    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        validator = container.frequencyValidator
        persistenceStorage = container.persistenceStorage
        persistenceStorage.shownInappsDictionary = [:]
    }
    
    override func tearDown() {
        validator = nil
        persistenceStorage = nil
        container = nil
        super.tearDown()
    }
    
    func test_once_lifetime_firstTime_shown() throws {
        let onceFrequency = OnceFrequency(kind: .lifetime)
        let inappFrequency: InappFrequency = .once(.init(kind: .lifetime))
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_once_lifetime_shownBefore() throws {
        persistenceStorage.shownInappsDictionary = ["1": Date(timeIntervalSince1970: 0)]
        let onceFrequency = OnceFrequency(kind: .lifetime)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_once_session_firstTime() throws {
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_once_session_shownBefore() throws {
        persistenceStorage.shownInappsDictionary = ["1": Date(timeIntervalSince1970: 0)]
        let onceFrequency = OnceFrequency(kind: .session)
        let inappFrequency: InappFrequency = .once(onceFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_periodic_seconds_firstTime() throws {
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_periodic_days_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .day, value: -2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_periodic_days_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .day, value: 0, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_days_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .day, value: 2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .days, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_hours_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .hour, value: -2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .hours, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_periodic_hours_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .hour, value: 0, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .hours, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_hours_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .hour, value: 2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .hours, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_minutes_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .minute, value: -2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .minutes, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_periodic_minutes_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .minute, value: 0, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .minutes, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_minutes_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .minute, value: 2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .minutes, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_seconds_alreadyShown_two_days_ago() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .second, value: -2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertTrue(validator.isValid(item: inapp))
    }
    
    func test_periodic_seconds_alreadyShown_today() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .second, value: 0, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_periodic_seconds_alreadyShown_in_future() throws {
        let calendar = Calendar.current
        let shownDate = calendar.date(byAdding: .second, value: 2, to: Date())!
        persistenceStorage.shownInappsDictionary = ["1": shownDate]
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 1)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    func test_frequency_is_zero() throws {
        let periodicFrequency = PeriodicFrequency(unit: .seconds, value: 0)
        let inappFrequency: InappFrequency = .periodic(periodicFrequency)
        let inapp = getInapp(frequency: inappFrequency)
        XCTAssertFalse(validator.isValid(item: inapp))
    }
    
    private func getInapp(frequency: InappFrequency) -> InApp {
        return InApp(id: "1",
                     sdkVersion: SdkVersion(min: 9, max: nil),
                     targeting: .true(TrueTargeting()),
                     frequency: frequency,
                     form: InAppForm(variants: [.unknown]))
    }
    
    private func getConfig(name: String) throws -> ConfigResponse {
        let bundle = Bundle(for: InAppTargetingRequestsTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}
