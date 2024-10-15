//
//  SDKLogsStatus.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

public enum SDKLogsStatus: Equatable {
    case ok
    case noData
    case elderLog(date: String)
    case latestLog(date: String)
    case largeSize

    public var value: String {
        switch self {
        case .ok:
            return "OK"
        case .noData:
            return "No data found"
        case .elderLog(let date):
            return "No data found. The elder log has date: \(date)"
        case .latestLog(let date):
            return "No data found. The latest log has date: \(date)"
        case .largeSize:
            return "The requested log size is too large"
        }
    }
}
