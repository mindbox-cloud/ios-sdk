//
//  MigrationManager.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class MigrationManager {

    private var migrations: [MigrationProtocol]

    private var localSdkVersionCode: Int

    private var persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
        self.localSdkVersionCode = Constants.Migration.sdkVersionCode

        self.migrations = [
            DateFormatMigration(),
            ShownInAppsIDsMigration(),
            ShownInAppsDictionaryMigration(),
            RemoveBackgroundTaskDataMigration(),
            DatabaseMetadataMigration(),
            FirstInitializationDateTimeMigration()
        ]
    }
}

// MARK: - MigrationManagerProtocol

extension MigrationManager: MigrationManagerProtocol {

    func migrate() {

        guard persistenceStorage.isInstalled else {
            let firstInstallationMessage = "[Migrations] The first installation. Migrations will not be performed."
            Logger.common(message: firstInstallationMessage, level: .info, category: .migration)
            persistenceStorage.versionCodeForMigration = localSdkVersionCode
            return
        }

        var migrationsStarted: Bool = false

        migrations
            .sorted { $0.version < $1.version }
            .forEach { migration in
                guard migration.isNeeded else { return }
                migrationsStarted = true
                do {
                    try migration.run()
                    Logger.common(message: "[Migration] Run migration: '\(migration.description)', version: \(migration.version)", level: .info, category: .migration)
                } catch {
                    Logger.common(message: "[Migration] Migration \(migration.version) failed. Description: \(migration.description). Error: \(error.localizedDescription)", level: .error, category: .migration)
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
