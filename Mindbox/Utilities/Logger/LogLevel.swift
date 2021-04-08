//
//  LogLevel.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 07.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

/// The `Loglevel` is used to distinguish between log messages level.
public enum LogLevel: Int, CaseIterable, Comparable, Equatable {
    
    case debug = 0     //  |
    case info = 1      //  |
    case `default` = 2 //  |
    case error = 3     //  |
    case fault = 4     //  V
    
    var emoji: String {
        switch self {
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
