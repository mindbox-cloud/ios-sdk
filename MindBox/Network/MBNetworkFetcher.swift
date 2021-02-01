//
//  MBNetworkFetcher.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBNetworkFetcher: NetworkFetcher {
    
    private let session: URLSession
    
    private let builder: URLRequestBuilder

    init(configuration: NetworkConfiguration) {
        self.builder = URLRequestBuilder(baseURL: configuration.baseURL)
        let sessionConfiguration: URLSessionConfiguration = .default
        sessionConfiguration.requestCachePolicy = configuration.cachePolicy
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutInterval
        sessionConfiguration.httpAdditionalHeaders = configuration.additionalHeaders
        self.session = URLSession(configuration: sessionConfiguration)
    }
    
    func request<T: BaseResponse>(route: Route, completion: @escaping Completion<T>) {
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            session.dataTask(with: urlRequest) { (data, response, error) in
                Log(data: data, response: response, error: error).withDate().make()
                do {
                    guard let response = response as? HTTPURLResponse else {
                        throw URLError(.unknown)
                    }
                    guard HTTPURLResponseStatusCodeValidator(statusCode: response.statusCode).evaluate() else {
                        throw URLError(.unsupportedURL)
                    }
                    guard let data = data else {
                        throw URLError(.badServerResponse)
                    }
                    let responseModel = ResponseModel<T>()
                    responseModel.rawData = data
                    responseModel.data = try JSONDecoder().decode(T.self, from: data)
//                    responseModel.request = requestModel
                    completion(.success(responseModel))

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
                    completion(.failure(error))
                }
 
            }.resume()
        } catch let error {
            completion(.failure(ErrorModel(errorKey: error.localizedDescription)))
        }
    }
    
    private func makeResponseModel<T: BaseResponse>(with data: Data) throws -> ResponseModel<T> {
        let responseModel = ResponseModel<T>()
        responseModel.rawData = data
        responseModel.data = try JSONDecoder().decode(T.self, from: data)
        
        return responseModel
    }
    
}
