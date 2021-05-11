//
//  EventRoute.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum EventRoute: Route {
    
    case asyncEvent(EventWrapper), customAsyncEvent(EventWrapper) , trackVisit(EventWrapper), pushDeleveried(EventWrapper)
    
    var method: HTTPMethod {
        switch self {
        case .asyncEvent,
             .customAsyncEvent,
             .trackVisit:
            return .post
        case .pushDeleveried:
            return .get
        }
    }
    
    var path: String {
        switch self {
        case .asyncEvent, .customAsyncEvent:
            return "/v3/operations/async"
        case .trackVisit:
            return "/v1.1/customer/mobile-track-visit"
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
                .appending(["endpointId": wrapper.endpoint])
        case .customAsyncEvent(let wrapper):
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return [:]
            }
            
            return makeBasicQueryParameters(with: wrapper)
                .appending(["operation": decoded.body.name])
                .appending(["endpointId": wrapper.endpoint])
        case .pushDeleveried(let wrapper):
            let decoded = BodyDecoder<PushDelivered>(decodable: wrapper.event.body)
            return makeBasicQueryParameters(with: wrapper)
                .appending(["uniqKey": decoded?.body.uniqKey ?? ""])
                .appending(["endpointId": wrapper.endpoint])
        case .trackVisit(let wrapper):
            return makeBasicQueryParameters(with: wrapper)
        }
    }
    
    var body: Data? {
        switch self {
        case .asyncEvent(let wrapper):
            return wrapper.event.body.data(using: .utf8)
        case .customAsyncEvent(let wrapper):
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return nil
            }
            
            return decoded.body.payload.data(using: .utf8)
        case .pushDeleveried:
            return nil
        case .trackVisit(let wrapper):
            guard let data = wrapper.event.body.data(using: .utf8),
                  var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                return nil
            }
            
            json["endpointId"] = wrapper.endpoint
            
            return try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
    }
    
    func makeBasicQueryParameters(with wrapper: EventWrapper) -> QueryParameters {
        ["transactionId": wrapper.event.transactionId,
         "deviceUUID": wrapper.deviceUUID,
         "dateTimeOffset": wrapper.event.dateTimeOffset]
    }
    
}

fileprivate struct TrackVisitBodyProxy: Codable {
    
    let ianaTimeZone: String
    let endpointId: String
    
    init(ianaTimeZone: String, endpointId: String) {
        self.ianaTimeZone = ianaTimeZone
        self.endpointId = endpointId
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

