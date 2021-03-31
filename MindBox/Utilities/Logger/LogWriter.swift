//
//  LogWriter.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 15.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import os

protocol LogWriter {
    func writeMessage(_ message: String, logLevel: LogLevel)
}

class ConsoleWriter: LogWriter {
    enum Method {
        case print, nslog
    }

    let method: Method

    init(method: Method = .nslog) {
        self.method = method
    }

    func writeMessage(_ message: String, logLevel: LogLevel) {
        switch method {
        case .print:
            print(message)
        case .nslog:
            NSLog("%@", message)
        }
    }
}

class OSLogWriter: LogWriter {
    let subsystem: String
    let category: String

    let log: OSLog

    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        log = OSLog(subsystem: subsystem, category: category)
    }

    func writeMessage(_ message: String, logLevel: LogLevel) {
        os_log("%{public}@", log: log, type: logLevel.asOSLogType, message)
    }

}

fileprivate extension LogLevel {
    
    var asOSLogType: OSLogType {
        switch self {
        case .error:
            return .error
        case .info:
            return .info
        case .debug:
            return .debug
        case .default,
             .warning:
            return .default
        }
    }
    
}
