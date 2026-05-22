//
//  NetworkFetcher.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol NetworkFetcher {
    func request<T>(
        type: T.Type,
        route: Route,
        needBaseResponse: Bool,
        completion: @escaping ((Result<T, MindboxError>) -> Void)
    ) where T: Decodable

    func request(
        route: Route,
        completion: @escaping ((Result<Void, MindboxError>) -> Void)
    )

    /// Returns the raw HTTP 2xx response body without parsing `BaseResponse`,
    /// so the caller can decide how to interpret it. 4xx, 5xx and network
    /// failures still surface as `MindboxError` through the shared response
    /// pipeline.
    func requestRaw(
        route: Route,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    )

    /// Cancels all ongoing network tasks.
    func cancelAllTasks()
}

extension NetworkFetcher {
    func request<T>(
        type: T.Type,
        route: Route,
        completion: @escaping ((Result<T, MindboxError>) -> Void)
    ) where T: Decodable {
        request(type: type, route: route, needBaseResponse: true, completion: completion)
    }
}
