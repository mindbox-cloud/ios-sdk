//
//  URLRequestBuilder.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct URLRequestBuilder {
    
    let domain: String
    
    init(domain: String) {
        self.domain = domain
    }
    
    func asURLRequest(route: Route) throws -> URLRequest {
        let components = makeURLComponents(for: route)

        guard let url = components.url else {
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
    
    private func makeURLComponents(for route: Route) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = route.path
        components.queryItems = makeQueryItems(for: route.queryParameters)
        
        return components
    }
    
    private func makeQueryItems(for parameters: QueryParameters?) -> [URLQueryItem]? {
        return parameters?.compactMap { URLQueryItem(name: $0.key, value: $0.value.description) }
    }
    
}
