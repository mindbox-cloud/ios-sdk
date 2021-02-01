//
//  MockApiService.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import MindBox

class MockApiService: APIService {

    // MARK: - Properties

    
    let baseURL: String = "MOCK"

    init() {
    }

    func sendRequest<T: Codable>(requestModel: RequestModel, completion: @escaping(Swift.Result<ResponseModel<T>, ErrorModel>) -> Void) {

        let data = try! Data(contentsOf: URL(fileURLWithPath: Bundle.init(for: MockApiService.self).path(forResource: "SuccessResponse", ofType: "json")!), options: NSData.ReadingOptions.mappedIfSafe)
        do {

            let responseModel = ResponseModel<T>()
            responseModel.rawData = data
            responseModel.data = try JSONDecoder().decode(T.self, from: data)
            responseModel.request = requestModel

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
