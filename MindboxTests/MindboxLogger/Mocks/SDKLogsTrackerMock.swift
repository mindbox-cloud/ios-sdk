//
//  SDKLogsTrackerMock.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 16.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class SDKLogsTrackerMock: SDKLogsTrackerProtocol {
    var lastBody: SDKLogsRequest?
    var requests: [SDKLogsRequest] = []
    
    func sendLogs(body: SDKLogsRequest) throws {
        lastBody = body
        requests.append(body)
        return
    }
}
