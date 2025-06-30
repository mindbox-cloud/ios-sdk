//
//  MigrationManager.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// A class responsible for managing and executing migrations.
/// It keeps a list of migrations, checks if they are needed, and runs them in the correct order.
final class MigrationManager {

    /// The list of migration objects that conform to `MigrationProtocol`.
    private var migrations: [MigrationProtocol]

    /// The local sdk version code used to determine whether migrations need to be performed.
    /// By default, it is set to `Constants.Migration.sdkVersionCode`.
    /// Changing this value in `convenience init` is used when writing tests.
    private var localSdkVersionCode: Int

    /// The persistence storage used for managing various application states,
    /// including migration state and other critical data. It provides methods
    /// for performing resets and managing configurations.
    private var persistenceStorage: PersistenceStorage

    /// Initializes the migration manager with the provided persistence storage.
    /// - Parameter persistenceStorage: The persistence storage used for managing various application states,
    ///                                 including migration state and other critical data. It provides methods
    ///                                 for performing resets and managing configurations.
    ///                                 
    /// - Attention: When adding new migrations, make sure they are added to the `migrations` array
    ///         in the correct order. The order of the migrations in this array determines the order
    ///         in which they are performed.
    ///         Currently, migrations are sorted by their internal version (see `MigrationProtocol.version`). This may change in the future.
    ///
    /// Example:
    /// ```
    /// self.migrations = [
    ///     Migration_1(),
    ///     Migration_2(),
    ///     Migration_3(),
    ///     Migration_4(),
    ///     // Add new migrations here
    /// ]
    /// ```
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
        self.localSdkVersionCode = Constants.Migration.sdkVersionCode

        self.migrations = [
            MigrationShownInAppsIds(),
            RemoveBackgroundTaskDataMigration()
        ]
    }
}

// MARK: - MigrationManagerProtocol

extension MigrationManager: MigrationManagerProtocol {

    /// Performs any necessary migrations. If this is the first installation, it sets the migration version code without performing migrations.
    /// If any migration that involves `Constants.Migration.sdkVersionCode` and `persistenceStorage.versionCodeForMigration` fails,
    /// a soft reset is performed on the persistence storage to ensure that the system remains in a consistent state.
    func migrate() {

        guard persistenceStorage.isInstalled else {
            let firstInstallationMessage = "[Migrations] The first installation. Migrations will not be performed."
            Logger.common(message: firstInstallationMessage, level: .info, category: .migration)
            persistenceStorage.versionCodeForMigration = localSdkVersionCode
            return
        }

        var migrationsStarted: Bool = false

        migrations
            .lazy
            .filter { $0.isNeeded }
            .sorted { $0.version < $1.version }
            .forEach { migration in
                migrationsStarted = true
                do {
                    try migration.run()
                    let message = "[Migration] Run migration: '\(migration.description)', version: \(migration.version)"
                    Logger.common(message: message, level: .info, category: .migration)
                } catch {
                    let errorMessage = "[Migration] Migration \(migration.version) failed. Description: \(migrations.description). Error: \(error.localizedDescription)"
                    Logger.common(message: errorMessage, level: .error, category: .migration)
                }
            }

        if persistenceStorage.versionCodeForMigration != localSdkVersionCode {
            Logger.common(message: "[Migrations] Migrations failed, soft reset memory", level: .info, category: .migration)
            persistenceStorage.softReset()
            persistenceStorage.versionCodeForMigration = localSdkVersionCode
            return
        }

        let message = migrationsStarted ? "[Migrations] Migrations have been successful" : "[Migrations] Migrations have been skipped"

        Logger.common(message: message, level: .info, category: .migration)
    }
}

// MARK: - Convenience initializer for testing purposes

extension MigrationManager {

    /// Convenience initializer for testing purposes. This initializer allows for the overwriting of
    /// all existing migrations and the local migration version.
    /// - Parameters:
    ///   - persistenceStorage: Persistence storage used for managing various application states,
    ///                         including migration state and other critical data. It provides methods
    ///                         for performing resets and managing configurations.
    ///   - migrations: Array of new migrations.
    ///   - sdkVersionCode: version for comparison with `persistenceStorage.versionCodeForMigration` 
    ///                     after all migrations have been performed.
    ///                     Used instead of `Constants.Migration.sdkVersionCode`
    convenience init(
        persistenceStorage: PersistenceStorage,
        migrations: [MigrationProtocol],
        sdkVersionCode: Int
    ) {
        self.init(persistenceStorage: persistenceStorage)
        self.localSdkVersionCode = sdkVersionCode
        self.migrations = migrations
    }
}
