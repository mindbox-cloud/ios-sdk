//
//  LogWriter.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import os

protocol LogWriter {
    func writeMessage(_ message: String, logLevel: LogLevel)
}

class OSLogWriter: LogWriter {
    
    let log: OSLog

    init(subsystem: String, category: String) {
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
        case .default:
            return .default
        case .fault:
            return .fault
        }
    }
    
}
