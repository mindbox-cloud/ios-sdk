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
    
    func requestTest<T>(
        type: T.Type,
        route: Route,
        needBaseResponse: Bool,
        completion: @escaping (Result<T, MindboxError>) -> Void
    ) -> Cancelable? where T: Decodable
}
