//
//  RemoveBackgroundTaskDataMigration.swift
//  Mindbox
//
//  Created by Sergei Semko on 6/26/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

final class RemoveBackgroundTaskDataMigration: MigrationProtocol {

    private let userDefaultsSuite = MBPersistenceStorage.defaults
    private let fileManager = FileManager.default
    
    private let backgroundsExecutionKey = "backgroundExecution"
    private let backgroundExecutionPlistName = "BackgroundExecution.plist"

    var description: String {
        "Migration removes background task data"
    }

    var isNeeded: Bool {
        
        let userDefaultsDeleteNeeded = userDefaultsSuite.value(forKey: backgroundsExecutionKey) != nil
        
        let fileURL = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backgroundExecutionPlistName)
        
        return userDefaultsDeleteNeeded || fileManager.fileExists(atPath: fileURL.path)
    }

    var version: Int {
        1
    }

    func run() throws {
        userDefaultsSuite.removeObject(forKey: backgroundsExecutionKey)
        
        let fileURL = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backgroundExecutionPlistName)
        
        // If file doesn't exist - will throw error `No such file or directory`
        try? fileManager.removeItem(at: fileURL)
    }
}
