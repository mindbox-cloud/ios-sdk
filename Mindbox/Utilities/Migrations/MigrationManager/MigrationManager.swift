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
}

enum MigrationConstants {
    static var sdkVersionCode = 2
}

// https://github.com/mindbox-cloud/ios-sdk/compare/develop...feature/MBX-3411-sdk-version-migration

final class MigrationManager {
    
    private var migrations: [MigrationProtocol]
    private var localVersionCode: Int
    private var persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
        self.localVersionCode = MigrationConstants.sdkVersionCode
        self.migrations = [
            Migration1(),
            Migration2(),
//            Migration4()
        ]
    }
    /// Convenience init for testing - overwrite all existing migrations and local migration contant
    /// - Parameters:
    ///   - persistenceStorage: Persistence storage -> UserDefaults
    ///   - migrations: Array of new migrations
    ///   - localVersionCode: version for comparison with persistenceStorage.versionCodeForMigration after all migrations have been performed
    convenience init(persistenceStorage: PersistenceStorage, migrations: [MigrationProtocol], localVersionCode: Int) {
        self.init(persistenceStorage: persistenceStorage)
        self.localVersionCode = localVersionCode
        self.migrations = migrations
    }
}

// MARK: - MigrationManagerProtocol
extension MigrationManager: MigrationManagerProtocol {
    func migrate() {
        migrations
            .lazy
            .filter { $0.isNeeded }
            .sorted { $0.version < $1.version }
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
        
        if persistenceStorage.versionCodeForMigration != localVersionCode {
            Logger.common(message: "[Migrations] Migrations failed, reset memory", level: .info, category: .migration)
            persistenceStorage.reset()
            persistenceStorage.versionCodeForMigration = localVersionCode
            return
        }
        
        Logger.common(message: "[Migrations] Migrations were successful")
    }
}
