//
//  EventRoute.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum EventRoute: Route {
    
    case asyncEvent(event: Event, configuration: MBConfiguration)
    
    var method: HTTPMethod {
        switch self {
        case .asyncEvent:
            return .post
        }
    }
    
    var path: String {
        switch self {
        case .asyncEvent:
            return "/v3/operations/async"
        }
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    var queryParameters: QueryParameters {
        switch self {
        case .asyncEvent(let event, let configuration):
            return [
                "endpointId": configuration.endpoint,
                "operation": event.type.rawValue,
                "deviceUUID": configuration.deviceUUID!,
                "transactionId": event.transactionId,
                "dateTimeOffset": event.dateTimeOffset
            ]
        }
    }
    
    var body: Data? {
        switch self {
        case .asyncEvent(let event, _):
            return event.body.data(using: .utf8)
        }
    }
    
    
}
