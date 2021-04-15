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
        print("failableRouteIndex: \(failableRouteIndex)")
        print("RoutesCount: \(routesCount)")
    }
    
    private var routesCount: Int = 0 {
        didSet {
            print("RoutesCount: \(routesCount)")
        }
    }
    
    var failableRouteIndex = Int.random(in: 0...9)
     
    private func errorForRoute() -> ErrorModel? {
        if routesCount >= 9 {
            routesCount = 0
            failableRouteIndex = Int.random(in: 0...9)
        }
        
        if routesCount == failableRouteIndex {
            let error: ErrorModel = ErrorModel(
                errorKey: ErrorKey.parsing.rawValue,
                rawError: nil
            )
            
            error.status = .InternalServerError
            error.httpStatusCode = 501
            error.responseStatusCode = 501
            
            routesCount += 1
            return error
        } else {
            routesCount += 1
            return nil
        }
    }
    
    func request(route: Route, completion: @escaping ((Result<Void, ErrorModel>) -> Void)) {
        if let error = errorForRoute() {
            completion(.failure(error))
        } else {
            completion(Result.success(()))
        }
    }
    
    func requestObject<T>(route: Route, completion: @escaping Completion<T>) where T : BaseResponse {
        if let error = errorForRoute() {
            completion(.failure(error))
        } else {
            let bundle = Bundle(for: MockNetworkFetcher.self)
            let path = bundle.path(forResource: "SuccessResponse", ofType: "json")!
            let url = URL(fileURLWithPath: path)
            let data = try! Data(contentsOf: url, options: .mappedIfSafe)
            do {
                let responseModel = ResponseModel<T>()
                responseModel.rawData = data
                responseModel.data = try JSONDecoder().decode(T.self, from: data)
                responseModel.route = route
                if responseModel.data != nil {
                    completion(Result.success(responseModel))
                } else {
                    completion(Result.failure(ErrorModel(errorKey: ErrorKey.general.rawValue)))
                }
            } catch let decodeError {
                let error: ErrorModel = ErrorModel(errorKey: ErrorKey.parsing.rawValue, rawError: decodeError)
                Log(error: error).withDate().make()
                completion(Result.failure(error))
            }
        }
    }
    
}
