//
//  DatabaseMetadataMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 10/1/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData

final class DatabaseMetadataMigration: MigrationProtocol {

    private var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)
    private var databaseRepo: MBDatabaseRepository? = DI.injectOrFail(DatabaseRepositoryProtocol.self) as? MBDatabaseRepository

    var description: String {
        "Migration metadata from MBDatabaseRepository CoreData to MBPersistenceStorage UserDefaults. Starting with SDK 2.14.2."
    }

    var isNeeded: Bool {
        let hasMDInfoUpdate = read(Int.self, .infoUpdate) != nil
        let hasMDInstanceId = read(String.self, .instanceId) != nil

        let needsCopyInfoUpdate = persistenceStorage.applicationInfoUpdateVersion == nil && hasMDInfoUpdate
        let needsCopyInstanceId = persistenceStorage.applicationInstanceId == nil && hasMDInstanceId

        let needsCleanup = (persistenceStorage.applicationInfoUpdateVersion != nil && hasMDInfoUpdate)
                        || (persistenceStorage.applicationInstanceId != nil && hasMDInstanceId)

        return needsCopyInfoUpdate || needsCopyInstanceId || needsCleanup
    }

    var version: Int {
        3
    }

    func run() throws {
        let infoUpdateVersion: Int? = read(Int.self, .infoUpdate)
        let instanceId: String?     = read(String.self, .instanceId)
        
        if persistenceStorage.applicationInfoUpdateVersion == nil {
            persistenceStorage.applicationInfoUpdateVersion = infoUpdateVersion
        }
        if persistenceStorage.applicationInstanceId == nil {
            persistenceStorage.applicationInstanceId = instanceId
        }
        
        clear(.infoUpdate)
        clear(.instanceId)
    }
    
    private func read<T>(_ type: T.Type, _ key: Constants.StoreMetadataKey) -> T? {
        guard let repo = databaseRepo else { return nil }
        
        let coordinator = repo.persistentContainer.persistentStoreCoordinator
        guard let store = coordinator.persistentStores.first else { return nil }
        
        return store.metadata[key.rawValue] as? T
    }
    
    private func clear(_ key: Constants.StoreMetadataKey) {
        guard let repo = databaseRepo else { return }
        let psc = repo.persistentContainer.persistentStoreCoordinator
        guard let store = psc.persistentStores.first else { return }

        var md = psc.metadata(for: store)
        md.removeValue(forKey: key.rawValue)
        psc.setMetadata(md, for: store)
    }
}
