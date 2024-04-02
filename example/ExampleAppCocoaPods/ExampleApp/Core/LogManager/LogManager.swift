//
//  LogManager.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import Foundation
import OSLog
import Mindbox

final class EALogManager {
    
    static let shared = EALogManager()
    
    private let fileManager: FileManagerProtocol
    private let logFileName = "appLogs.txt"
    
    private init(fileManager: FileManagerProtocol = EAFileManager()) {
        self.fileManager = fileManager
        self.log("\n\n\nNew start \(Array(repeating: "=", count: 100).joined())")
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
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            Logger.logManager.warning("Couldn't find bundle id")
            return
        }
        
        let suiteName = "group.cloud.Mindbox.\(bundleIdentifier)"
        
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Logger.logManager.warning("Couldn't read UD with suiteName: \(suiteName)")
            return
        }
        
        let allEntries = userDefaults.dictionaryRepresentation()
        var logString = "UserDefaults:\n"
        
        let configurationDataKey = "MBPersistenceStorage-configurationData"
        if let data = allEntries[configurationDataKey] as? Data {
            do {
                let configuration = try JSONDecoder().decode(MBConfiguration.self, from: data)
                let configurationDescription = """
                Configuration:
                    Endpoint: \(configuration.endpoint)
                    Domain: \(configuration.domain)
                    PreviousInstallationId: \(String(describing: configuration.previousInstallationId))
                    PreviousDeviceUUID: \(String(describing: configuration.previousDeviceUUID))
                    SubscribeCustomerIfCreated: \(configuration.subscribeCustomerIfCreated)
                    ShouldCreateCustomer: \(configuration.shouldCreateCustomer)
                    ImageLoadingMaxTimeInSeconds: \(String(describing: configuration.imageLoadingMaxTimeInSeconds))
                """
                logString += configurationDescription
            } catch {
                Logger.logManager.error("Failed to decode configuration for key \(configurationDataKey): \(error.localizedDescription)")
            }
        }
        
        for (key, value) in allEntries where key != configurationDataKey {
            logString += "\(key): \(value)\n"
        }
        
        log(logString)
    }
    
    func readLogs() -> String {
        do {
            let logData = try fileManager.read(fileNamed: logFileName)
            
            if let logString = String(data: logData, encoding: .utf8) {
                return logString
            } else {
                return "Logs are not readable in UTF-8."
            }
        } catch {
            Logger.logManager.error("Error reading logs: \(error.localizedDescription)")
            return "Failed to read logs: \(error.localizedDescription)"
        }
    }
}
