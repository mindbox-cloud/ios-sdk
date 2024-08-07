//
//  MigrationsImplementingTheProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/1/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

//func migrateShownInAppsIds() {
//    if let oldIds = shownInAppsIds, !oldIds.isEmpty {
//        Logger.common(message: "Starting migration of shownInAppsIds. Total IDs to migrate: \(oldIds.count)", level: .debug, category: .inAppMessages)
//        let migrationTimestamp = Date(timeIntervalSince1970: 0)
//        var newFormat: [String: Date] = [:]
//
//        for id in oldIds {
//            newFormat[id] = migrationTimestamp
//        }
//        shownInappsDictionary = newFormat
//        shownInAppsIds = nil
//        Logger.common(message: "Migration completed successfully. All IDs are migrated and old IDs list is cleared.", level: .debug, category: .inAppMessages)
//    }
//}

final class MigrationShownInAppIds: MigrationProtocol {
    
    private var persistenceStorage: PersistenceStorage = DI.injectOrFail(PersistenceStorage.self)
    
    var description: String {
        "Migration shownInAppsIds to shownInappsDictionary. Starting with SDK 2.10.0"
    }
    
    var isNeeded: Bool {
//        if let oldShownInAppsIds = persistenceStorage.shownInAppsIds, !oldShownInAppsIds.isEmpty {
//            return true
//        } else {
//            return false
//        }
        
        return persistenceStorage.shownInAppsIds?.isEmpty == false
    }
    
    var version: Int {
        return 0
    }
    
    func run() throws {
        guard let oldShownInAppsIds = persistenceStorage.shownInAppsIds else {
            return
        }
        Logger.common(message: "Starting migration of shownInAppsIds. Total IDs to migrate: \(oldShownInAppsIds.count)", level: .debug, category: .inAppMessages)
        
        let migrationTimestamp = Date(timeIntervalSince1970: 0)
        var newFormat: [String: Date] = [:]
        
        for id in oldShownInAppsIds {
            newFormat[id] = migrationTimestamp
        }
        persistenceStorage.shownInappsDictionary = newFormat
        persistenceStorage.shownInAppsIds = nil
        
        Logger.common(message: "Migration completed successfully. All IDs are migrated and old IDs list is cleared.", level: .debug, category: .inAppMessages)
    }
}
