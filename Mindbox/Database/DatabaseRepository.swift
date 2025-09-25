//
//  DatabaseRepository.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/23/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

protocol DatabaseRepository: AnyObject {
    // lifecycle / limits
    var limit: Int { get }
    var lifeLimitDate: Date? { get }
    var deprecatedLimit: Int { get }
    var onObjectsDidChange: (() -> Void)? { get set }

    // metadata
    var infoUpdateVersion: Int? { get set }
    var installVersion: Int? { get set }
    var instanceId: String? { get set }

    // CRUD
    func create(event: Event) throws
    func readEvent(by transactionId: String) throws -> Event?
    func update(event: Event) throws
    func delete(event: Event) throws

    // queries/maintenance
    func query(fetchLimit: Int, retryDeadline: TimeInterval) throws -> [Event]
    func removeDeprecatedEventsIfNeeded() throws
    func countDeprecatedEvents() throws -> Int
    func erase() throws
    
    @discardableResult
    func countEvents() throws -> Int
}

extension DatabaseRepository {
    func query(fetchLimit: Int) throws -> [Event] {
        try query(fetchLimit: fetchLimit, retryDeadline: Constants.Database.retryDeadline)
    }
}
