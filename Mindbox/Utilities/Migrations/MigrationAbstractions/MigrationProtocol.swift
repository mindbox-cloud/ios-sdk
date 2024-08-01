//
//  MigrationProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/1/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

/// A protocol that defines the requirements for a migration object.
/// Migration objects are responsible for performing specific migrations,
/// which may include but are not limited to migrations in a persistent storage system.
/// Each migration object provides a description, a condition that determines whether the migration
/// is required, and a version number that is used for sorting and comparison. The migration itself
/// is performed by the `run` method, which may throw errors if the migration fails.
protocol MigrationProtocol {
    
    /// A textual description of the migration.
    var description: String { get }
    
    /// A condition that determines whether the migration is required.
    /// - Note: Make sure that `isNeeded` returns `true` in cases where the migration is based on `MigrationConstant`.
    ///         If this is not the case, and the migration fails, performing a `softReset` is considered acceptable.
    var isNeeded: Bool { get }
    
    /// The version number of the migration, which can be used to sort and determine
    /// whether to apply the migration.
    var version: Int { get }
    
    /// Performs the migration. If the migration fails, an error is thrown.
    /// - Throws: An error if the migration fails.
    func run() throws
}
