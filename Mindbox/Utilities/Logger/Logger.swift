//
//  Loger.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import os


public class MBLogger {
    
    /**
     ### Levels:
     1. none
     2. debug 🪲
     3. info ℹ️
     4. default 💡
     5. error ‼️
     6. fault ⚠️
     */
    public var logLevel: LogLevel = .none
        
    private enum ExecutionMethod {
        case sync(lock: NSRecursiveLock)
        case async(queue: DispatchQueue)
    }
    
    private let executionMethod: ExecutionMethod
    
    public init() {
        #if DEBUG
            executionMethod = .sync(lock: NSRecursiveLock())
        #else
            executionMethod = .async(queue: DispatchQueue(label: "Mindbox.serial.log.queue", qos: .utility))
        #endif
    }

    func log(level: LogLevel, message: String, category: LogCategory, subsystem: String) {
        guard logLevel.rawValue >= level.rawValue else {
            return
        }
        let categories: [LogCategory] = LogCategory.allCases
        guard categories.contains(category) else {
            return
        }
        let writer = makeWriter(subsystem: subsystem, category: category)
        switch executionMethod {
        case let .async(queue: queue):
            queue.async { writer.writeMessage(message, logLevel: level) }
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
        Log(message)
            .meta(filename: fileName, line: line, funcName: funcName)
            .subsystem(Mindbox.shared.container?.utilitiesFetcher.hostApplicationName ?? "cloud.Mindbox.UndefinedHostApplication")
            .level(level)
            .category(.general)
            .make()
    }
    
    private func makeWriter(subsystem: String, category: LogCategory) -> LogWriter {
        return OSLogWriter(subsystem: subsystem, category: category.rawValue.capitalized)
    }
    
}
