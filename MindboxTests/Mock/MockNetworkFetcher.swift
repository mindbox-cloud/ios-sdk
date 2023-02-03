//
//  MockNetworkFetcher.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class MockNetworkFetcher: NetworkFetcher {
    init() {
    }

    func request(route: Route, completion: @escaping ((Result<Void, MindboxError>) -> Void)) {
        completion(Result.success(()))
    }

    func request<T>(type: T.Type, route: Route, needBaseResponse: Bool, completion: @escaping ((Result<T, MindboxError>) -> Void)) where T : Decodable {
        let bundle = Bundle(for: MockNetworkFetcher.self)
        let path = bundle.path(forResource: "SuccessResponse", ofType: "json")!
        let url = URL(fileURLWithPath: path)
        let data = try! Data(contentsOf: url, options: .mappedIfSafe)
        do {
            let decoded = try JSONDecoder().decode(type, from: data)
            completion(Result.success(decoded))
        } catch let decodeError {
            let error: MindboxError = MindboxError(.init(errorKey: .parsing, rawError: decodeError, statusCode: nil))
            Logger.error(error)
            completion(Result.failure(error))
        }
    }
}
