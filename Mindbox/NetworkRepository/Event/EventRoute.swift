//
//  EventRoute.swift
//  Mindbox
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
            return makeBasicQueryParameters(with: wrapper)
                .appending(["operation": wrapper.event.type.rawValue])
            
        case .pushDeleveried(let wrapper):
            let decoded = BodyDecoder<PushDelivered>(decodable: wrapper.event.body)
            return makeBasicQueryParameters(with: wrapper)
                .appending(["uniqKey": decoded?.body.uniqKey ?? ""])
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
    
    func makeBasicQueryParameters(with wrapper: EventWrapper) -> QueryParameters {
        ["endpointId": wrapper.endpoint,
         "deviceUUID": wrapper.deviceUUID,
         "transactionId": wrapper.event.transactionId,
         "dateTimeOffset": wrapper.event.dateTimeOffset]
    }
    
}

fileprivate extension QueryParameters {

    func appending(_ values: @autoclosure () -> QueryParameters) -> QueryParameters {
        var copy = self
        values().forEach { (key, value) in
            copy[key] = value
        }
        return copy
    }
    
}

