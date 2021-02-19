//
//  EventRoute.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum EventRoute: Route {
    
    case asyncEvent(EventWrapper), pushDeleveried(EventWrapper)
    
    var method: HTTPMethod {
        switch self {
        case .asyncEvent:
            return .post
        case .pushDeleveried:
            return .get
        }
    }
    
    var path: String {
        switch self {
        case .asyncEvent:
            return "/v3/operations/async"
        case .pushDeleveried:
            return "/mobile-push/delivered"
        }
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    var queryParameters: QueryParameters {
        switch self {
        case .asyncEvent(let wrapper):
            return [
                "endpointId": wrapper.endpoint,
                "operation": wrapper.event.type.rawValue,
                "deviceUUID": wrapper.deviceUUID,
                "transactionId": wrapper.event.transactionId,
                "dateTimeOffset": wrapper.event.dateTimeOffset
            ]
        case .pushDeleveried(let wrapper):
            let decoded = BodyDecoder<PushDelivered>(decodable: wrapper.event.body)
            return [
                "endpointId": wrapper.endpoint,
                "deviceUUID": wrapper.deviceUUID,
                "transactionId": wrapper.event.transactionId,
                "dateTimeOffset": wrapper.event.dateTimeOffset,
                "uniqKey": decoded?.body.uniqKey ?? ""
            ]
        }
    }
    
    var body: Data? {
        switch self {
        case .asyncEvent(let wrapper):
            return wrapper.event.body.data(using: .utf8)
        case .pushDeleveried:
            return nil
        }
    }
    
    
}
