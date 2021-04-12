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
 1. none
 2. debug 🪲
 3. info ℹ️
 4. default 💡
 5. error ‼️
 6. fault ⚠️
 */
public enum LogLevel: Int, CaseIterable, Comparable, Equatable {
    
    case none = 0   //  X
    case debug      //  |
    case info       //  |
    case `default`  //  |
    case error      //  |
    case fault      //  V
    
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
