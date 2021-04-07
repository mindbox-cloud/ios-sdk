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
    
    public var isEnabled: Bool

    public var logLevel: LogLevel = .default
        
    private enum ExecutionMethod {
        case sync(lock: NSRecursiveLock)
        case async(queue: DispatchQueue)
    }
    
    private let executionMethod: ExecutionMethod
    
    public init() {
        #if DEBUG
            isEnabled = true
            executionMethod = .sync(lock: NSRecursiveLock())
        #else
            isEnabled = false
            executionMethod = .async(queue: DispatchQueue(label: "Mindbox.serial.log.queue", qos: .utility))
        #endif
    }
    
    func log(level: LogLevel, message: String, category: LogCategory) {
        guard isEnabled else {
            return
        }
        guard logLevel.rawValue <= level.rawValue else {
            return
        }
        let categories: [LogCategory] = LogCategory.allCases
        guard categories.contains(category) else {
            return
        }
        let writer = makeWriter(category: category, level: level)
        switch executionMethod {
        case let .async(queue: queue):
            queue.async { writer.writeMessage(message, logLevel: level) }
        case let .sync(lock: lock):
            lock.lock(); defer { lock.unlock() }
            writer.writeMessage(message, logLevel: level)
        }
    }
    
    public func log(
        level: LogLevel,
        message: String,
        fileName: String = #file,
        line: Int = #line,
        funcName: String = #function
    ) {
        Log(message)
            .meta(filename: fileName, line: line, funcName: funcName)
            .level(level)
            .category(.general)
            .make()
    }
    
    private func makeWriter(category: LogCategory, level: LogLevel) -> LogWriter {
        return OSLogWriter(subsystem: "cloud.Mindbox", category: category.rawValue.capitalized)
    }
    
}
