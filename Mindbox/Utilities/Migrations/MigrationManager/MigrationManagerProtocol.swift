//
//  MigrationManagerProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/1/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

/// A protocol that defines the requirements for a migration manager.
/// The migration manager is responsible for performing a series of migrations
/// to update the application data to a new version.
protocol MigrationManagerProtocol {

    /// Attempts to perform all necessary migrations. If a migration fails,
    /// a `softReset()` is performed on the persistence storage to ensure
    /// that the system remains in a consistent state.
    ///
    /// - Note: The `softReset()` method is responsible for clearing certain parts of
    ///         the persistence storage to revert the system to a stable state.
    ///         It is defined in the `PersistenceStorage` protocol.
    func migrate()
}
