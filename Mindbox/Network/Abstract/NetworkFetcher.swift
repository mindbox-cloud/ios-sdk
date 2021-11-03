//
//  NetworkFetcher.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol NetworkFetcher {
    func request<T>(
            type: T.Type,
            route: Route,
            withResultMindboxCompetion completion: @escaping (ResultMindbox) -> Void
        ) where T: Decodable


    func request<T>(
        type: T.Type,
        route: Route,
        completion: @escaping ((Result<T, MindboxError>) -> Void)
    ) where T: Decodable

    func request(
        route: Route,
        completion: @escaping ((Result<Void, MindboxError>) -> Void)
    )
}
