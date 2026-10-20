//
//  NoopDatabaseRepository.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/29/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

final class NoopDatabaseRepository: DatabaseRepositoryProtocol {
    
    var limit: Int { 10_000 }
    var lifeLimitDate: Date?
    var deprecatedLimit: Int { 0 }
    var onObjectsDidChange: (() -> Void)?

    func create(event: Event) throws { }
    func readEvent(by transactionId: String) throws -> Event? { nil }
    func update(event: Event) throws { }
    func delete(event: Event) throws { }

    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event] { [] }
    func removeDeprecatedEventsIfNeeded() throws { }
    func countDeprecatedEvents() throws -> Int { 0 }
    func erase() throws { }
    func countEvents() throws -> Int { 0 }
}
