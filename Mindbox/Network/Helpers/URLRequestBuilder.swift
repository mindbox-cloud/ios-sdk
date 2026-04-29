//
//  URLRequestBuilder.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct URLRequestBuilder {

    let domain: String
    let operationsDomain: String?

    init(domain: String, operationsDomain: String? = nil) {
        self.domain = domain
        self.operationsDomain = operationsDomain
    }

    func asURLRequest(route: Route) throws -> URLRequest {
        let components = try makeURLComponents(for: route)

        guard let url = components.url else {
            Logger.common(message: "Bad url. [URL]: \(String(describing: components.url))", level: .error, category: .network)
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        route.headers?.forEach {
            urlRequest.addValue($0.value, forHTTPHeaderField: $0.key)
        }
        urlRequest.httpBody = route.body
        urlRequest.httpMethod = route.method.rawValue.uppercased()

        return urlRequest
    }

    private func makeURLComponents(for route: Route) throws -> URLComponents {
        let baseURL = HostNormalizer.toBaseURLString(resolvedHost(for: route))

        // Fail fast: if the base URL is unparseable, we used to fall back to an
        // empty `URLComponents()` — `components.url` then returned a relative URL
        // (just the path), which silently sent the request to a bogus target.
        guard var components = URLComponents(string: baseURL) else {
            Logger.common(message: "Failed to build base URL components. [Base]: \(baseURL)", level: .error, category: .network)
            throw URLError(.badURL)
        }

        components.path = route.path
        components.queryItems = makeQueryItems(for: route.queryParameters)

        return components
    }

    private func resolvedHost(for route: Route) -> String {
        switch route.baseURLKind {
        case .domain:
            return domain
        case .operations:
            return operationsDomain ?? domain
        }
    }

    private func makeQueryItems(for parameters: QueryParameters?) -> [URLQueryItem]? {
        return parameters?.compactMap { URLQueryItem(name: $0.key, value: $0.value.description) }
    }
}
