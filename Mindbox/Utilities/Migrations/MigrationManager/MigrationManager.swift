//
//  MigrationManager.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/29/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol MigrationManagerProtocol {
    func migrate()
    func migrate(migrationConstant: Int)
}

enum MigrationConstants {
    static var sdkVersionCode = 2
}

// https://github.com/mindbox-cloud/ios-sdk/compare/develop...feature/MBX-3411-sdk-version-migration

final class MigrationManager {
    
    private var migrations: [MigrationProtocol]
    private var persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
        self.migrations = [
            Migration1(),
            Migration2()
        ]
    }
    
    /// Convenience init for testing - overwrite all existing migrations
    /// - Parameters:
    ///   - persistenceStorage: Persistence storage -> UserDefaults
    ///   - migrations: New migrations
    convenience init(persistenceStorage: PersistenceStorage, migrations: [MigrationProtocol]) {
        self.init(persistenceStorage: persistenceStorage)
        self.migrations = migrations
        print(migrations)
        print(migrations.count)
    }
}

// MARK: - MigrationManagerProtocol
extension MigrationManager: MigrationManagerProtocol {
    func migrate() {
        migrate(migrationConstant: MigrationConstants.sdkVersionCode)
    }
    
    func migrate(migrationConstant: Int = MigrationConstants.sdkVersionCode) {
        migrations
            .sorted { $0.version < $1.version }
            .filter { $0.isNeeded }
            .forEach { migration in
                do {
                    try migration.run()
                    Logger.common(
                        message: "[Migration] Run migration: \(migration.description), version: \(migration.version)",
                        level: .info,
                        category: .migration
                    )
                } catch {
                    Logger.common(
                        message: "[Migration] Migration \(migration.description) failed. Error: \(error.localizedDescription)",
                        level: .error,
                        category: .migration
                    )
                }
            }
        
        if persistenceStorage.versionCodeForMigration != migrationConstant {
            Logger.common(message: "[Migrations] Migrations failed, reset memory", level: .info, category: .migration)
            persistenceStorage.reset()
            persistenceStorage.versionCodeForMigration = migrationConstant
            return
        }
        
        Logger.common(message: "[Migrations] Migrations were successful")
    }
}
