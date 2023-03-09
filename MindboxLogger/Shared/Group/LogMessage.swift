//
//  LogMessage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

public struct LogMessage {
    public let timestamp: Date
    public let message: String
    
    public var description: String {
        return timestamp.toString(withFormat: .utc) + " | " + message
    }
}
