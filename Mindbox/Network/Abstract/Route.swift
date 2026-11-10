//
//  Route.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

enum RouteBaseURL: Equatable {
    case domain
    case operations
    case tracking(String)
}

protocol Route {

    var method: HTTPMethod { get }

    var path: String { get }

    var headers: HTTPHeaders? { get }

    var queryParameters: QueryParameters { get }

    var body: Data? { get }

    func loggableBody(from body: Data?) -> Data?

    var baseURLKind: RouteBaseURL { get }
}

extension Route {
    var baseURLKind: RouteBaseURL { .domain }

    func loggableBody(from body: Data?) -> Data? { body }
}
