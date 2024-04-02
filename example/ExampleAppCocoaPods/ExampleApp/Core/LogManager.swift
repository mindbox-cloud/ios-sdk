//
//  LogManager.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import Foundation
import OSLog

final class EALogManager {
    
    private let fileManager: FileManagerProtocol
    private let logFileName = "appLogs.txt"
    
    init(fileManager: FileManagerProtocol = EAFileManager()) {
        self.fileManager = fileManager
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        
        if let logData = logMessage.data(using: .utf8) {
            do {
                try self.fileManager.append(toFileNamed: self.logFileName, data: logData)
            } catch {
                Logger.logManager.error("Error writing \(error.localizedDescription)")
            }
        }
    }
    
    func logUserDefaultsMindbox() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let suiteName = "group.cloud.Mindbox.\(bundleIdentifier)"
            if let userDefaults = UserDefaults(suiteName: suiteName) {
                let allEntries = userDefaults.dictionaryRepresentation()
                var logString = "UserDefaults:\n"
                
                for (key, value) in allEntries {
                    logString += "\(key): \(value)\n"
                }
                
                log(logString)
            }
        }
    }
}
