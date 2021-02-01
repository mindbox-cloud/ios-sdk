//
//  APIService.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
protocol APIService: class {
    func sendRequest<T: BaseResponse>(requestModel: RequestModel, completion: @escaping(Swift.Result<ResponseModel<T>, ErrorModel>) -> Void)
}

class NetworkManagerProvider: APIService {
    
    // MARK: - Properties

    var baseURL: String {
        get {
            return configurationStorage.domain
        }
    }

    let configurationStorage: IConfigurationStorage

    init(configurationStorage: IConfigurationStorage) {
        self.configurationStorage = configurationStorage
    }
    
    func sendRequest<T: BaseResponse>(requestModel: RequestModel, completion: @escaping(Swift.Result<ResponseModel<T>, ErrorModel>) -> Void) {

        let request = requestModel.urlRequest(baseURL: baseURL)
        Log(request: request).withDate().make()
        URLSession.shared.dataTask(with: request) {data, response, error in

            Log(data: data, response: response, error: error).withDate().make()

            do {
                guard let response = response as? HTTPURLResponse else {
                    throw NSError()
                }

                guard (200...210).contains(response.statusCode)  else {
                    throw NSError()
                }

                guard let data = data else {
                    throw NSError()
                }

                let responseModel = ResponseModel<T>()
                responseModel.rawData = data
                responseModel.data = try JSONDecoder().decode(T.self, from: data)
//                responseModel.request = requestModel

                completion(Result.success(responseModel))
            } catch let decodeError {
                let error: ErrorModel = ErrorModel(errorKey: ErrorKey.parsing.rawValue, rawError: decodeError)

                if let data = data,
                   let object = try? JSONDecoder().decode(BaseResponse.self, from: data) {
                    error.status = object.status
                    error.errorMessage = object.errorMessage
                    error.errorId = object.errorId
                    error.httpStatusCode = object.httpStatusCode
                }

                error.responseStatusCode = (response as? HTTPURLResponse)?.statusCode

                Log(error: error).withDate().make()
                completion(Result.failure(error))
            }

        }.resume()
    }

}
