//
//  LogManager.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import Foundation
import OSLog
import Mindbox

enum UserDefaultsSdkKeys: String, CaseIterable {
    case installationId = "MBPersistenceStorage-installationId"
    case deviceUUID = "MBPersistenceStorage-deviceUUID"
    case apnsToken = "MBPersistenceStorage-apnsToken"
    case apnsTokenSaveDate = "MBPersistenceStorage-apnsTokenSaveDate"
    case configurationData = "MBPersistenceStorage-configurationData"
    case isNotificationsEnabled = "MBPersistenceStorage-isNotificationsEnabled"
    case installationData = "MBPersistenceStorage-installationData"
}

final class EALogManager {
    
    static let shared = EALogManager()
    
    private let fileManager: FileManagerProtocol
    private let logFileName = "appLogs.txt"
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM, HH:mm:ss:SSS"
        return formatter
    }()
    
    private init(fileManager: FileManagerProtocol = EAFileManager()) {
        self.fileManager = fileManager
        logLaunchApp()
    }
    
    private func logLaunchApp() {
        let timestamp = dateFormatter.string(from: Date())
        let message = "New launch app \(Array(repeating: "=", count: 123).joined())"
        let logMessage = "\n\n\n[\(timestamp)] \(message)\n"
        
        if let logData = logMessage.data(using: .utf8) {
            do {
                try self.fileManager.append(toFileNamed: self.logFileName, data: logData)
            } catch {
                Logger.logManager.error("Error writing \(error.localizedDescription)")
            }
        }
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
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
        
        var logString = "UserDefaults:\n"
        
        UserDefaultsSdkKeys.allCases.forEach { key in
            if key == .configurationData, let data = userDefaults.data(forKey: key.rawValue) {
                do {
                    let configuration = try JSONDecoder().decode(MBConfiguration.self, from: data)
                    let configurationDescription = """
                        \nConfiguration:
                            Endpoint: \(configuration.endpoint)
                            Domain: \(configuration.domain)
                            PreviousInstallationId: \(configuration.previousInstallationId ?? "nil")
                            PreviousDeviceUUID: \(configuration.previousDeviceUUID ?? "nil")
                            SubscribeCustomerIfCreated: \(configuration.subscribeCustomerIfCreated)
                            ShouldCreateCustomer: \(configuration.shouldCreateCustomer)
                            ImageLoadingMaxTimeInSeconds: \(String(describing: configuration.imageLoadingMaxTimeInSeconds))\n\n
                        """
                    logString += configurationDescription
                } catch {
                    Logger.logManager.error("Failed to decode configuration for key \(key.rawValue): \(error.localizedDescription)")
                }
            } else if let value = userDefaults.object(forKey: key.rawValue) {
                logString += "\(key.rawValue.split(separator: "-").last ?? ""): \(value)\n"
            }
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
