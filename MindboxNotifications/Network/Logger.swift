//
//  Logger.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import os

class Logger {
    public static func log(_ message: String, type: OSLogType) {
        let log = OSLog(subsystem: "cloud.Mindbox", category: "Notifications")

        os_log("%{public}@", log: log, type: type, message)
    }
}
