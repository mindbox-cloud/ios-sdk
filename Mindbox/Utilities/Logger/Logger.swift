//
//  Loger.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import os

protocol Logger: class {
    
    func log(text: String, category: LogCategory, level: LogLevel)
    
}

enum LogCategory: String {
    
    case general
    case network
    case database
    case delivery
    case background
    case notification
    
    var emoji: String {
        switch self {
        case .general:
            return "🤖"
        case .network:
            return "📡"
        case .database:
            return "📖"
        case .delivery:
            return "⚙️"
        case .background:
            return "🕳"
        case .notification:
            return "✉️"
        }
    }
    
}

public enum LogLevel: String {
    
    case error
    case info
    case debug
    case `default`
    case fault
    
    var emoji: String {
        switch self {
        case .error:
            return "[‼️]"
        case .info:
            return "[💡]"
        case .debug:
            return "[🪲]"
        case .`default`:
            return "[🔎]"
        case .fault:
            return "[⚠️]"
        }
    }
    
}

enum ExecutionMethod {
    case sync(lock: NSRecursiveLock)
    case async(queue: DispatchQueue)
}


class MBLogger: Logger {
    
    let executionMethod: ExecutionMethod
    
    func log(text: String, category: LogCategory, level: LogLevel) {
        let writer = makeWriter(category: category, level: level)
        let config = LogConfiguration()
        guard config.enabledCategories.contains(category) else {
            return
        }
        switch executionMethod {
        case let .async(queue: queue):
            queue.async { writer.writeMessage(text, logLevel: level) }
        case let .sync(lock: lock):
            lock.lock(); defer { lock.unlock() }
            writer.writeMessage(text, logLevel: level)
        }
    }
    
    func makeWriter(category: LogCategory, level: LogLevel) -> LogWriter {
        return OSLogWriter(subsystem: "cloud.Mindbox", category: category.rawValue.capitalized)
    }

    init() {
        #if DEBUG
            executionMethod = .sync(lock: NSRecursiveLock())
        #else
            executionMethod = .async(queue: DispatchQueue(label: "serial.log.queue", qos: .utility))
        #endif
    }
    
}
