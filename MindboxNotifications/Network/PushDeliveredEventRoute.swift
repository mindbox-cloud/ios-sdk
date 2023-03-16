//
//  PushDeliveredEventRoute.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

struct PushDeliveredEventRoute: Route {
    let wrapper: EventWrapper
    init(wrapper: EventWrapper) {
        self.wrapper = wrapper
    }

    var method: HTTPMethod {
        return .get
    }

    var path: String {
        return "/mobile-push/delivered"
    }

    var headers: HTTPHeaders? {
        return nil
    }

    var queryParameters: QueryParameters {
        let decoded = BodyDecoder<PushDelivered>(decodable: wrapper.event.body)
        return makeBasicQueryParameters(with: wrapper)
            .appending(["uniqKey": decoded?.body.uniqKey ?? ""])
            .appending(["endpointId": wrapper.endpoint])
    }

    var body: Data? {
        return nil
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
