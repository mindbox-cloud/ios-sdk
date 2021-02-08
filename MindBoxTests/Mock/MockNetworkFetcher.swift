//
//  MockNetworkFetcher.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import MindBox

class MockNetworkFetcher: NetworkFetcher {
    
    init() {
    }
    
    func request(route: Route, completion: @escaping ((Result<Void, ErrorModel>) -> Void)) {
        completion(Result.success(()))
    }
    
    func requestObject<T>(route: Route, completion: @escaping Completion<T>) where T : BaseResponse {
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
