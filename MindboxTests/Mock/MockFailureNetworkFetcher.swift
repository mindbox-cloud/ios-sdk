//
//  MockFailureNetworkFetcher.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 24.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class MockFailureNetworkFetcher: NetworkFetcher {
    init() {
        //        print("failableRouteIndex: \(failableRouteIndex)")
        //        print("RoutesCount: \(routesCount)")
    }

    private var routesCount: Int = 0 {
        didSet {
            //            print("RoutesCount: \(routesCount)")
        }
    }
    
    var failableRouteIndex = Int.random(in: 0...9)
    
    private func errorForRoute() -> ErrorModel? {
        if routesCount >= 9 {
            let error: ErrorModel = ErrorModel(
                errorKey: ErrorKey.parsing.rawValue,
                rawError: nil
            )

            error.status = .InternalServerError
            error.httpStatusCode = 501
            error.responseStatusCode = 501
            
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

    func request<T>(type: T.Type, route: Route, completion: @escaping ((Result<T, MindboxError>) -> Void)) where T: Decodable {
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
                let error: MindboxError = MindboxError(errorKey: ErrorKey.parsing.rawValue, rawError: decodeError)
                Log(error: error).withDate().make()
                completion(Result.failure(error))
            }
        }
    }
}
