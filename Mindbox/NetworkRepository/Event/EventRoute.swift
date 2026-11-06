//
//  EventRoute.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

enum EventRoute: Route {
    case syncEvent(EventWrapper)
    case asyncEvent(EventWrapper)
    case customAsyncEvent(EventWrapper)
    case trackVisit(EventWrapper)

    var method: HTTPMethod {
        switch self {
        default:
            return .post
        }
    }

    var baseURLKind: RouteBaseURL {
        if case let .asyncEvent(wrapper) = self, let trackingHost = wrapper.trackingIds?.trackingHost {
            return .tracking(trackingHost)
        }
        return .operations
    }

    var path: String {
        switch self {
        case .syncEvent:
            return "/v3/operations/sync"
        case .asyncEvent, .customAsyncEvent:
            return "/v3/operations/async"
        case .trackVisit:
            return "/v1.1/customer/mobile-track-visit"
        }
    }

    var headers: HTTPHeaders? {
        switch self {
        case .syncEvent:
            return ["Accept": "application/json"]
        default:
            return nil
        }
    }

    var queryParameters: QueryParameters {
        switch self {
        case let .asyncEvent(wrapper):
            return makeBasicQueryParameters(with: wrapper)
                .appending(["operation": wrapper.event.type.operationName])
                .appending(["endpointId": wrapper.endpoint])
        case let .customAsyncEvent(wrapper):
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return [:]
            }

            return makeBasicQueryParameters(with: wrapper)
                .appending(["operation": decoded.body.name])
                .appending(["endpointId": wrapper.endpoint])
        case let .syncEvent(wrapper):
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return [:]
            }

            return QueryParameters()
                .appending(["deviceUUID": wrapper.deviceUUID])
                .appending(["operation": decoded.body.name])
                .appending(["endpointId": wrapper.endpoint])
        case let .trackVisit(wrapper):
            return makeBasicQueryParameters(with: wrapper)
        }
    }

    var body: Data? {
        switch self {
        case let .asyncEvent(wrapper):
            guard let ids = wrapper.trackingIds else { return wrapper.event.body.data(using: .utf8) }
            return jsonBody(wrapper.event.body, merging: ["ids": ids.jsonArray])
        case let .customAsyncEvent(wrapper), let .syncEvent(wrapper):
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return nil
            }

            return decoded.body.payload.data(using: .utf8)
        case let .trackVisit(wrapper):
            return jsonBody(wrapper.event.body, merging: ["endpointId": wrapper.endpoint])
        }
    }

    func loggableBody(from body: Data?) -> Data? {
        guard case let .asyncEvent(wrapper) = self, let ids = wrapper.trackingIds else { return body }
        return ids.masking(body)
    }

    private func jsonBody(_ rawBody: String, merging fields: [String: Any]) -> Data? {
        guard let data = rawBody.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return nil
        }

        json.merge(fields) { _, new in new }

        return try? JSONSerialization.data(withJSONObject: json)
    }

    func makeBasicQueryParameters(with wrapper: EventWrapper) -> QueryParameters {
        ["transactionId": wrapper.event.transactionId,
         "deviceUUID": wrapper.deviceUUID,
         "dateTimeOffset": wrapper.event.dateTimeOffset]
    }
}

fileprivate extension QueryParameters {
    func appending(_ values: @autoclosure () -> QueryParameters) -> QueryParameters {
        var copy = self
        values().forEach { key, value in
            copy[key] = value
        }
        return copy
    }
}
