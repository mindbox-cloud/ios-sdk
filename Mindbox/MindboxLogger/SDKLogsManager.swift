//
//  SDKLogsManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation
import MindboxLogger

protocol SDKLogsManagerProtocol {
    func sendLogs(logs: [Monitoring.Logs])
}

class SDKLogsManager: SDKLogsManagerProtocol {

    private enum Constants {
        static let logsSizeLimit = 800000 // In bytes
    }

    private let persistenceStorage: PersistenceStorage
    private let eventRepository: EventRepository

    init(persistenceStorage: PersistenceStorage,
         eventRepository: EventRepository) {
        self.persistenceStorage = persistenceStorage
        self.eventRepository = eventRepository
    }

    func sendLogs(logs: [Monitoring.Logs]) {
        guard !logs.isEmpty else { return }
        guard let deviceUUID = persistenceStorage.deviceUUID, !deviceUUID.isEmpty else {
            Logger.common(message: "[SDKLogs] Skip monitoring logs: deviceUUID is missing", level: .error, category: .general)
            return
        }
        let deviceTarget = MD5Hash(deviceUUID: deviceUUID)
        var handledLogsRequestIds = persistenceStorage.handledlogRequestIds ?? []
        for log in logs {
            guard !handledLogsRequestIds.contains(log.requestId) else {
                Logger.common(message: "[SDKLogs] Skip request \(log.requestId): already handled", level: .debug, category: .general)
                continue
            }
            guard deviceTarget == MD5Hash(hex: log.target) else {
                Logger.common(message: "[SDKLogs] Skip request \(log.requestId): target \(log.target) doesn't match device target \(deviceTarget.hex)", level: .debug, category: .general)
                continue
            }
            handledLogsRequestIds.append(log.requestId)
            guard let from = log.from.toDate(withFormat: .utc),
                  let to = log.to.toDate(withFormat: .utc) else {
                Logger.common(message: "[SDKLogs] Skip request \(log.requestId): malformed dates from: \"\(log.from)\", to: \"\(log.to)\"", level: .error, category: .general)
                continue
            }

            do {
                let body = try getBody(from: from, to: to, requestID: log.requestId)
                let event = Event(type: .sdkLogs, body: BodyEncoder(encodable: body).body)
                Logger.common(message: "[SDKLogs] Sending logs for request \(log.requestId), period \(log.from) – \(log.to), status: \(body.status), lines: \(body.content.count)", level: .info, category: .general)
                eventRepository.send(event: event) { result in
                    if case let .failure(error) = result {
                        Logger.common(message: "[SDKLogs] Sending logs for request \(log.requestId) failed: \(error.localizedDescription)", level: .error, category: .general)
                    }
                }
            } catch {
                Logger.common(message: "[SDKLogs] Failed to build logs body for request \(log.requestId): \(error.localizedDescription)", level: .error, category: .general)
            }
        }

        self.persistenceStorage.handledlogRequestIds = handledLogsRequestIds
    }

    func getBody(from: Date, to: Date, requestID: String) throws -> SDKLogsRequest {
        let firstLog = try MBLoggerCoreDataManager.shared.getFirstLog()
        let lastLog = try MBLoggerCoreDataManager.shared.getLastLog()
        let fetchedLogs = try MBLoggerCoreDataManager.shared.fetchPeriod(from, to)
        let status = getStatus(firstLog: firstLog,
                               lastLog: lastLog,
                               logs: fetchedLogs,
                               from: from,
                               to: to)
        let actualLogs = actualLogs(allLogs: fetchedLogs)

        return SDKLogsRequest(status: status.value,
                                  requestId: requestID,
                                  content: actualLogs)
    }

    func getStatus(firstLog: LogMessage?, lastLog: LogMessage?, logs: [LogMessage], from: Date, to: Date) -> SDKLogsStatus {
        if let firstLog = firstLog, firstLog.timestamp > to {
            return .elderLog(date: firstLog.timestamp.toString(withFormat: .utc))
        } else if let lastLog = lastLog, lastLog.timestamp < from {
            return .latestLog(date: lastLog.timestamp.toString(withFormat: .utc))
        } else if getLogsSize(logs) > Constants.logsSizeLimit {
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
