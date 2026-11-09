//
//  EventRoute.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct EventRoute: Route {
    let wrapper: EventWrapper

    init(_ wrapper: EventWrapper) {
        self.wrapper = wrapper
    }

    private var request: Event.Operation.Request {
        wrapper.event.type.request
    }

    var method: HTTPMethod {
        .post
    }

    var baseURLKind: RouteBaseURL {
        if case .sdkOperation = request, let trackingHost = wrapper.trackingIds?.trackingHost {
            return .tracking(trackingHost)
        }
        return .operations
    }

    var path: String {
        switch request {
        case .customSyncOperation:
            return "/v3/operations/sync"
        case .sdkOperation, .customAsyncOperation:
            return "/v3/operations/async"
        case .trackVisit:
            return "/v1.1/customer/mobile-track-visit"
        }
    }

    var headers: HTTPHeaders? {
        switch request {
        case .customSyncOperation:
            return ["Accept": "application/json"]
        case .sdkOperation, .customAsyncOperation, .trackVisit:
            return nil
        }
    }

    var queryParameters: QueryParameters {
        switch request {
        case let .sdkOperation(operation):
            return makeBasicQueryParameters()
                .appending(["operation": operation])
                .appending(["endpointId": wrapper.endpoint])
        case .customAsyncOperation:
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return [:]
            }

            return makeBasicQueryParameters()
                .appending(["operation": decoded.body.name])
                .appending(["endpointId": wrapper.endpoint])
        case .customSyncOperation:
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return [:]
            }

            return QueryParameters()
                .appending(["deviceUUID": wrapper.deviceUUID])
                .appending(["operation": decoded.body.name])
                .appending(["endpointId": wrapper.endpoint])
        case .trackVisit:
            return makeBasicQueryParameters()
        }
    }

    var body: Data? {
        switch request {
        case .sdkOperation:
            guard let ids = wrapper.trackingIds else { return wrapper.event.body.data(using: .utf8) }
            return jsonBody(wrapper.event.body, merging: ["ids": ids.jsonArray])
        case .customAsyncOperation, .customSyncOperation:
            guard let decoded = BodyDecoder<CustomEvent>(decodable: wrapper.event.body) else {
                return nil
            }

            return decoded.body.payload.data(using: .utf8)
        case .trackVisit:
            return jsonBody(wrapper.event.body, merging: ["endpointId": wrapper.endpoint])
        }
    }

    func loggableBody(from body: Data?) -> Data? {
        guard case .sdkOperation = request, let ids = wrapper.trackingIds else { return body }
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

    private func makeBasicQueryParameters() -> QueryParameters {
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
