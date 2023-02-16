//
//  SDKLogsTracker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

protocol SDKLogsTrackerProtocol: AnyObject {
    func sendLogs(body: SDKLogsRequest) throws
}

class SDKLogsTracker: SDKLogsTrackerProtocol {

    private let databaseRepository: MBDatabaseRepository

    init(databaseRepository: MBDatabaseRepository) {
        self.databaseRepository = databaseRepository
    }
    
    func sendLogs(body: SDKLogsRequest) throws {
        let event = Event(type: .sdkLogs, body: BodyEncoder(encodable: body).body)
        try databaseRepository.create(event: event)
    }
}
