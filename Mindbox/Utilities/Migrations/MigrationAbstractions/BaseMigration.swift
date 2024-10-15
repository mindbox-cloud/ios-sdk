//
//  BaseMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

/// A base class that implements the `MigrationProtocol` and provides common functionality
/// for all migration objects. Subclasses must override specific properties and methods to
/// define the migration behavior.
///
/// This class manages the persistence storage and provides a template method for performing
/// migrations, including automatic version incrementing. Subclasses must override and implement
/// the `performMigration` method and the `description`, `isNeeded`, and `version` properties.
///
/// - Important: The `run` method is marked as `final` and cannot be overridden by subclasses. Implement `performMigration` instead.
/// - Note: When creating a migration based on `BaseMigration` (with auto-increment of `versionCodeForMigration`),
///         make sure that you also increment the `MigrationConstant.sdkVersionCode`.
class BaseMigration: MigrationProtocol {

    /// The persistence storage used to manage the migration state.
    var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)

    /// Performs the specific migration logic. 
    /// Subclasses must implement this method to define the actual migration steps.
    /// - Throws: An error if the migration fails.
    func performMigration() throws {
        fatalError("Subclasses must implement the `performMigration` method without calling super.")
    }

    // MARK: MigrationProtocol

    /// A textual description of the migration. 
    /// Subclasses must override this property.
    var description: String {
        fatalError("Subclasses must implement the `description` property.")
    }

    /// A condition that determines whether the migration is required.
    /// Subclasses must override this property.
    var isNeeded: Bool {
        fatalError("Subclasses must implement the `isNeeded` property.")
    }

    /// The version number of the migration, which can be used to sort and determine
    /// whether to apply the migration. 
    /// Subclasses must override this property.
    var version: Int {
        fatalError("Subclasses must implement the `version` property.")
    }

    /// Executes the migration by calling the `performMigration` method. If the migration is
    /// successful, it increments the version in the `persistenceStorage`. 
    /// This method is `final` and cannot be overridden by subclasses.
    /// - Throws: An error if the migration fails.
    final func run() throws {
        do {
            try performMigration()
            let versionCode = persistenceStorage.versionCodeForMigration ?? 0
            persistenceStorage.versionCodeForMigration = versionCode + 1
        } catch {
            throw error
        }
    }
}
