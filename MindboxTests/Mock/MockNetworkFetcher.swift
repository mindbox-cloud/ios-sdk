//
//  MockNetworkFetcher.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

// swiftlint:disable force_try force_unwrapping

class MockNetworkFetcher: NetworkFetcher {
    var data: Data?
    var error: MindboxError?

    init() {
        let bundle = Bundle(for: MockNetworkFetcher.self)
        let path = bundle.path(forResource: "SuccessResponse", ofType: "json")!
        let url = URL(fileURLWithPath: path)
        let data = try! Data(contentsOf: url, options: .mappedIfSafe)
        self.data = data
    }

    func request(route: Route, completion: @escaping ((Result<Void, MindboxError>) -> Void)) {
        if let error = error {
            completion(Result.failure(error))
        } else {
            completion(Result.success(()))
        }
    }

    func request<T>(type: T.Type, route: Route, needBaseResponse: Bool, completion: @escaping ((Result<T, MindboxError>) -> Void)) where T: Decodable {
        if let error = error {
            completion(.failure(error))
        } else if let data = data {
            do {
                let decoded = try JSONDecoder().decode(type, from: data)
                completion(.success(decoded))
            } catch let decodeError {
                let error = MindboxError(.init(errorKey: .parsing, rawError: decodeError, statusCode: nil))
                completion(.failure(error))
            }
        }
    }
}
