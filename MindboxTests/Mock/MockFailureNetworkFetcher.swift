//
//  MockFailureNetworkFetcher.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 24.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

// swiftlint:disable force_try force_unwrapping

class MockFailureNetworkFetcher: NetworkFetcher {
    private var hasFailed = false
    
    func request(route: any Route, completion: @escaping (Result<Void, MindboxError>) -> Void) {
        if !hasFailed {
            hasFailed = true
            completion(
                .failure(
                    .internalError(
                        .init(errorKey: .serverError, rawError: nil)
                    )
                )
            )
        } else {
            completion(.success(()))
        }
    }
    
    func request<T>(type: T.Type, route: any Route, needBaseResponse: Bool, completion: @escaping (Result<T, MindboxError>) -> Void) where T : Decodable {
        if !hasFailed {
            hasFailed = true
            completion(.failure(.internalError(.init(
                errorKey: .parsing,
                rawError: nil
            ))))
        } else {
            let data = MockFailureNetworkFetcher.successData
            do {
                let decoded = try JSONDecoder().decode(type, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.internalError(.init(
                    errorKey: .parsing,
                    rawError: error
                ))))
            }
        }
    }
    
    private static let successData: Data = {
        let bundle = Bundle(for: MockNetworkFetcher.self)
        let url = bundle.url(forResource: "SuccessResponse", withExtension: "json")!
        return try! Data(contentsOf: url)
    }()
    
    func cancelAllTasks() {}
}
