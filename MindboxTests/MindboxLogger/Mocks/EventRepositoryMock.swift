//
//  EventRepositoryMock.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 16.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class EventRepositoryMock: EventRepository {
    
    var lastBody: SDKLogsRequest?
    var requests: [SDKLogsRequest] = []
    
    func send(event: Event, completion: @escaping (Result<Void, MindboxError>) -> Void) {
        guard let body = BodyDecoder<SDKLogsRequest>(decodable: event.body)?.body else {
            return
        }
        
        lastBody = body
        requests.append(body)
        return
    }
    
    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T : Decodable {
        return
    }
}
