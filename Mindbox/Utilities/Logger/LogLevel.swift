//
//  LogLevel.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 07.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

/**
 Logging levels supported by the sdk.
 
 ### Levels:
 0. debug 🪲
 1. info ℹ️
 2. default 💡
 3. error ‼️
 4. fault ⚠️
 5. none
 */
public enum LogLevel: Int, CaseIterable, Comparable, Equatable {
    case debug = 0
    case info = 1
    case `default` = 2
    case error = 3
    case fault = 4
    case none = 5
    
    var emoji: String {
        switch self {
        case .none:
            return ""
        case .debug:
            return "[🪲]"
        case .info:
            return "[ℹ️]"
        case .`default`:
            return "[💡]"
        case .error:
            return "[‼️]"
        case .fault:
            return "[⚠️]"
        }
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
}
