//
//  SDKLogsRequest.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 15.02.2023.
//

import Foundation

struct SDKLogsRequest: Codable {
    let status: String
    let requestId: String
    let content: [String]
}

struct SDKLogsRoute: Route {
    var method: HTTPMethod { .post }
    var path: String { "/v3/operations/async/MobileSdk.Logs" }
    var headers: HTTPHeaders? { nil }
    var queryParameters: QueryParameters { .init() }
    var body: Data?

    func makeBasicQueryParameters(with wrapper: EventWrapper) -> QueryParameters {
        ["transactionId": wrapper.event.transactionId,
         "deviceUUID": wrapper.deviceUUID,
         "dateTimeOffset": wrapper.event.dateTimeOffset,
         "operation": wrapper.event.type.rawValue,
         "endpointId": wrapper.endpoint]
    }
}
