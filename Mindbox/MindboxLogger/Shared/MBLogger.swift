//
//  MBLogger.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 02.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import os
import CoreData

public class MBLogger {
    
    public static let shared = MBLogger()
    
    /**
     ### Levels:
     0. debug - 🪲
     1. info - ℹ️
     2. default - 💡
     3. error - ‼️
     4. fault - ⚠️
     5. none
     
     - Note: `.error` by default; `.none` for disable logging
     */
    public var logLevel: LogLevel = .debug
        
    private enum ExecutionMethod {
        case sync(lock: NSRecursiveLock)
        case async(queue: DispatchQueue)
    }
    
    private let executionMethod: ExecutionMethod
    
    private init() {
        #if DEBUG
            executionMethod = .sync(lock: NSRecursiveLock())
        #else
            executionMethod = .async(queue: DispatchQueue(label: "Mindbox.serial.log.queue", qos: .utility))
        #endif
    }

    func log(level: LogLevel, message: String, date: Date, category: LogCategory, subsystem: String) {
        switch executionMethod {
        case .sync(lock: let lock):
            lock.lock();
            defer { lock.unlock() }
            self.writeToCD(message: message, timestamp: date)
        case .async(queue: let queue):
            queue.async {
                self.writeToCD(message: message, timestamp: date)
            }
        }
        
        guard logLevel.rawValue <= level.rawValue else {
            return
        }
        let categories: [LogCategory] = LogCategory.allCases
        guard categories.contains(category) else {
            return
        }
        let writer = makeWriter(subsystem: subsystem, category: category)
        
        switch executionMethod {
        case let .async(queue: queue):
            queue.async {
                writer.writeMessage(message, logLevel: level)
            }
        case let .sync(lock: lock):
            lock.lock(); defer { lock.unlock() }
            writer.writeMessage(message, logLevel: level)
        }
    }
    
    /**
     Method to write log in Xcode debug output as well in Console.app.
     
     - Important:
     To filter SDK logs in _Console.app_ use __subsystem__:
     your bundle identifier which is defined by the CFBundleIdentifier key in the bundle’s information property list.
     
     - Warning:
     If sdk could't find your bundleID, your logs will be under
     subsystem __"cloud.Mindbox.UndefinedHostApplication"__
     
     - Parameters:
        - level: LogLevel of the log
        - message: Log message
        - fileName: By default it uses #file
        - line: By default it uses #line
        - funcName: By default it uses #function
     */
    public func log(
        level: LogLevel,
        message: String,
        fileName: String = #file,
        line: Int = #line,
        funcName: String = #function
    ) {
        let subsystem = Bundle.main.bundleIdentifier ?? "cloud.Mindbox.UndefinedHostApplication"
        Logger.common(message: message,
                      level: level,
                      category: .general,
                      subsystem: subsystem,
                      fileName: fileName,
                      line: line,
                      funcName: funcName)
    }
}

private extension MBLogger {
    private func makeWriter(subsystem: String, category: LogCategory) -> LogWriter {
        return OSLogWriter(subsystem: subsystem, category: category.rawValue.capitalized)
    }
    
    private func writeToCD(message: String, timestamp: Date = Date()) {
        do {
            try MBLoggerCoreDataManager.shared.create(message: message, timestamp: timestamp)
        } catch {
            assertionFailure()
        }
    }
}
