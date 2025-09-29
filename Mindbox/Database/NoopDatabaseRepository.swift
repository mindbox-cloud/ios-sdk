//
//  NoopDatabaseRepository.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/29/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

final class NoopDatabaseRepository: DatabaseRepository {
    
    var limit: Int { 10_000 }
    var lifeLimitDate: Date?
    var deprecatedLimit: Int { 0 }
    var onObjectsDidChange: (() -> Void)?

    var infoUpdateVersion: Int? {
        get { nil }
        set { /* no-op */ } // swiftlint:disable:this unused_setter_value
    }
    var installVersion: Int? {
        get { nil }
        set { /* no-op */ } // swiftlint:disable:this unused_setter_value
    }
    var instanceId: String? {
        get { nil }
        set { /* no-op */ } // swiftlint:disable:this unused_setter_value
    }

    func create(event: Event) throws { /* no-op */ }
    func readEvent(by transactionId: String) throws -> Event? { nil }
    func update(event: Event) throws { /* no-op */ }
    func delete(event: Event) throws { /* no-op */ }

    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws { /* no-op */ }
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws { /* no-op */ }
    func countEvents() throws -> Int { 0 }
}
