//
//  APIService.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
protocol APIService: class {
    func sendRequest<T: BaseResponce>(request: RequestModel, completion: @escaping(Swift.Result<T, ErrorModel>) -> Void)
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
    
    func sendRequest<T: BaseResponce>(request: RequestModel, completion: @escaping(Swift.Result<T, ErrorModel>) -> Void) {

        // FIX: -
//        if request.isLoggingEnabled.request {
//            APILogManager.req(request, baseURL: baseURL)
//        }

        URLSession.shared.dataTask(with: request.urlRequest(baseURL: baseURL)) {data, response, error in

            guard let response = response as? HTTPURLResponse else {
                return
            }

            do {
                guard let data = data else {
                    throw NSError()
                }

                let object = try JSONDecoder().decode(T.self, from: data)
                completion(Result.success(object))
            } catch let decodeError {
                let error: ErrorModel = ErrorModel(errorKey: ErrorKey.parsing.rawValue, rawError: decodeError)
                do {
                    guard let data = data else {
                        throw NSError()
                    }
					 let object = try JSONDecoder().decode(ErrorResponce.self, from: data)
                    error.status = object.status
                    error.errorMessage = object.errorMessage
                    error.errorId = object.errorId
                    error.httpStatusCode = object.httpStatusCode
                } catch _ {

                }

                error.responseStatusCode = response.statusCode
                APILogManager.err(error)
                completion(Result.failure(error))
            }

        }.resume()
    }
}

class MockManagerProvider: APIService {

    // MARK: - Properties

    let baseURL: String = "MOCK"

    init() {
    }

    func sendRequest<T: Codable>(request: RequestModel, completion: @escaping(Swift.Result<T, ErrorModel>) -> Void) {

        // FIX
//        if request.isLoggingEnabled.request {
//            APILogManager.req(request, baseURL: baseURL)
//        }
        let data = try! Data(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "Response", ofType: "json")!), options: NSData.ReadingOptions.mappedIfSafe)
        do {
            let responseModel = try JSONDecoder().decode(ResponseModel<T>.self, from: data)
            responseModel.rawData = data
            responseModel.request = request
            // FIX
//            if request.isLoggingEnabled.response {
//                APILogManager.res(responseModel, baseURL: baseURL)
//            }

            if let data = responseModel.data {
                completion(Result.success(data))
            } else {
                completion(Result.failure(ErrorModel(errorKey: ErrorKey.general.rawValue)))
            }
        } catch let decodeError {
            let error: ErrorModel = ErrorModel(errorKey: ErrorKey.parsing.rawValue, rawError: decodeError)
            APILogManager.err(error)
            completion(Result.failure(error))
        }
    }
}
