//
//  SDKLogsRequest.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

struct SDKLogsRequest: Codable {
    let status: String
    let requestId: String
    let content: [String]
}
