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
    
    init() {
    }

    private var routesCount: Int = 0
    
    var failableRouteIndex = Int.random(in: 0...9)
    
    private func errorForRoute() -> MindboxError? {
        if routesCount >= 9 {
            let error: MindboxError = .internalError(.init(
                errorKey: .parsing,
                rawError: nil
            ))
            
            return error
        }
        
        routesCount += 1
        return nil
    }

    func request(route: Route, completion: @escaping ((Result<Void, MindboxError>) -> Void)) {
        if let error = errorForRoute() {
            completion(.failure(error))
        } else {
            completion(Result.success(()))
        }
    }

    func request<T>(type: T.Type, route: Route, needBaseResponse: Bool, completion: @escaping ((Result<T, MindboxError>) -> Void)) where T: Decodable {
        if let error = errorForRoute() {
            completion(.failure(error))
        } else {
            let bundle = Bundle(for: MockNetworkFetcher.self)
            let path = bundle.path(forResource: "SuccessResponse", ofType: "json")!
            let url = URL(fileURLWithPath: path)
            let data = try! Data(contentsOf: url, options: .mappedIfSafe)
            do {
                let decoded = try JSONDecoder().decode(type, from: data)
                completion(Result.success(decoded))
            } catch let decodeError {
                let error = MindboxError(.init(errorKey: .parsing, rawError: decodeError))
                completion(Result.failure(error))
            }
        }
    }
}
