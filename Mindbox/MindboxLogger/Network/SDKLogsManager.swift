//
//  SDKLogsManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

protocol SDKLogsManagerProtocol {
    func sendLogs(logs: [InAppConfigResponse.Monitoring.Logs])
}

class SDKLogsManager: SDKLogsManagerProtocol {
    
    private enum Constants {
        static let logsSizeLimit = 800000 // In bytes
    }
    
    private let logsTracker: SDKLogsTrackerProtocol
    private let persistenceStorage: PersistenceStorage
    
    init(logsTracker: SDKLogsTrackerProtocol,
         persistenceStorage: PersistenceStorage) {
        self.logsTracker = logsTracker
        self.persistenceStorage = persistenceStorage
    }
    
    func sendLogs(logs: [InAppConfigResponse.Monitoring.Logs]) {
        var handledLogsRequestIds = persistenceStorage.handledlogRequestIds ?? []
        for log in logs {
            if !handledLogsRequestIds.contains(log.requestId) && persistenceStorage.deviceUUID == log.deviceUUID.uppercased() {
                handledLogsRequestIds.append(log.requestId)
                guard let from = log.from.toDate(withFormat: .utc),
                      let  to = log.to.toDate(withFormat: .utc) else {
                    return
                }
                
                do {
                    let firstLog = try MBLoggerCoreDataManager.shared.getFirstLog()
                    let lastLog = try MBLoggerCoreDataManager.shared.getLastLog()
                    let fetchedLogs = try MBLoggerCoreDataManager.shared.fetchPeriod(from, to)
                    let status = getStatus(firstLog: firstLog,
                                           lastLog: lastLog,
                                           logs: fetchedLogs,
                                           from: from,
                                           to: to)
                    let actualLogs = actualLogs(allLogs: fetchedLogs)
                    
                    let body = SDKLogsRequest(status: status.value,
                                              requestId: log.requestId,
                                              content: actualLogs)
                    try logsTracker.sendLogs(body: body)
                } catch {
                    
                }
            }
        }
        
        self.persistenceStorage.handledlogRequestIds = handledLogsRequestIds
    }
    
    func getStatus(firstLog: LogMessage?, lastLog: LogMessage?, logs: [LogMessage], from: Date, to: Date) -> SDKLogsStatus {
        if let firstLog = firstLog, firstLog.timestamp > to {
            return .elderLog(date: firstLog.timestamp.toString(withFormat: .utc))
        } else if let lastLog = lastLog, lastLog.timestamp < from {
            return .latestLog(date: lastLog.timestamp.toString(withFormat: .utc))
        } else if getLogsSize(logs) > Constants.logsSizeLimit  {
            return .largeSize
        } else if logs.isEmpty {
            return .noData
        }
        
        return .ok
    }
    
    private func getLogsSize(_ logs: [LogMessage]) -> Int {
        return logs.reduce(0) { $0 + $1.description.utf8.count }
    }
    
    func actualLogs(allLogs: [LogMessage]) -> [String] {
        var logs = allLogs
        var totalSize = getLogsSize(logs)
        
        while totalSize > Constants.logsSizeLimit {
            for index in (0..<logs.count).reversed() {
                let logMessage = logs[index]
                let size = logMessage.description.utf8.count
                logs.remove(at: index)
                totalSize -= size
                if totalSize <= Constants.logsSizeLimit {
                    break
                }
            }
        }
        
        let logsDescriptionArray = logs.map({ $0.description })
        return logsDescriptionArray
    }
}
