//
//  Loger.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum MBLoggerChanels: String {
    case system = "🤖"
    case network = "📡"
    case database = "📖"
    case delivery = "⚙️"
    case background = "🕳"
    case notification = "✉️"
}

protocol ILogger: class {
    func log(inChanel: MBLoggerChanels, text: String, level: LogType?)
}

class MBLogger: ILogger {
    let executionMethod: ExecutionMethod
    let writer: LogWriter

    func log(inChanel: MBLoggerChanels, text: String, level: LogType?) {
        let config = LogerConfiguration()

        if config.enableChanels.contains(inChanel) {
            switch executionMethod {
            case let .async(queue: queue):
                queue.async { self.writer.writeMessage(text, logLevel: level ?? .debug) }
            case let .sync(lock: lock):
                lock.lock(); defer { lock.unlock() }
                writer.writeMessage(text, logLevel: level ?? .debug)
            }
        }
    }

    init() {
        if #available(iOS 12.0, *) {
            writer = OSLogWriter(subsystem: "MindBox", category: "InternalLog")
        } else {
            writer = ConsoleWriter()
        }

        #if DEBUG
            executionMethod = .sync(lock: NSRecursiveLock())
        #else
            executionMethod = .async(queue: DispatchQueue(label: "serial.log.queue", qos: .utility))
        #endif
    }
}
