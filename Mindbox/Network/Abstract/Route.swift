//
//  Route.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

enum RouteBaseURL {
    case domain
    /// Falls back to `domain` when no operations host is configured.
    case operations
}

protocol Route {

    var method: HTTPMethod { get }

    var path: String { get }

    var headers: HTTPHeaders? { get }

    var queryParameters: QueryParameters { get }

    var body: Data? { get }

    var baseURLKind: RouteBaseURL { get }
}

extension Route {
    var baseURLKind: RouteBaseURL { .domain }
}
