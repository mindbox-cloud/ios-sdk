//
//  LogWriter.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 15.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import os

public protocol LogWriter {
    func writeMessage(_ message: String, logLevel: LogType)
}

open class ConsoleWriter: LogWriter {
    public enum Method {
        case print, nslog
    }

    private let method: Method

    public init(method: Method = .nslog) {
        self.method = method
    }

    open func writeMessage(_ message: String, logLevel: LogType) {
        switch method {
        case .print:
            print(message)
        case .nslog:
            NSLog("%@", message)
        }
    }
}

open class OSLogWriter: LogWriter {
    public let subsystem: String
    public let category: String

    private let log: OSLog

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        log = OSLog(subsystem: subsystem, category: category)
    }

    open func writeMessage(_ message: String, logLevel: LogType) {
        let type = logType(forLogLevel: logLevel)

        os_log("%@", log: log, type: type, message)
    }

    open func logType(forLogLevel logLevel: LogType) -> OSLogType {
        switch logLevel {
        case LogType.debug: return .debug
        case LogType.info: return .info
        case LogType.warning: return .default
        case LogType.error, LogType.severe: return .error
        default: return .default
        }
    }
}
