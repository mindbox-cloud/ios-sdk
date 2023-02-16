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
    var method: HTTPMethod { .get }
    var path: String { "/geo" }
    var headers: HTTPHeaders? { nil }
    var queryParameters: QueryParameters { .init() }
    var body: Data?
}
