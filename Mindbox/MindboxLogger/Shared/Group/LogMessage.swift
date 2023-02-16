//
//  LogMessage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

struct LogMessage {
    let timestamp: Date
    let message: String
    
    var description: String {
        return timestamp.toString(withFormat: .utc) + " | " + message
    }
}
