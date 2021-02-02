//
//  MBNetworkFetcher.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit.UIDevice

class MBNetworkFetcher: NetworkFetcher {
            
    private let configuration: ConfigurationStorage

    init(
        configuration: ConfigurationStorage,
        utilitiesFetcher: UtilitiesFetcher
    ) {
        self.configuration = configuration
        
        
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknow"
        let appVersion = utilitiesFetcher.appVerson ?? "unknow"
        let hostApplicationName = utilitiesFetcher.sdkVersion ?? "unknow"

        let userAgent: String = "\(hostApplicationName)\(appVersion), \(DeviceModelHelper.os)\(DeviceModelHelper.iOSVersion), Apple, \(DeviceModelHelper.model)"

        URLSession.shared.configuration.httpAdditionalHeaders = [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": sdkVersion,
            "User-Agent": userAgent,
            "Content-Type": "application/json; charset=utf-8"
        ]
    }
    
    func request<T: BaseResponse>(route: Route, completion: @escaping Completion<T>) {
        let builder = URLRequestBuilder(domain: configuration.domain)
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            Log(request: urlRequest).withDate().make()
            URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
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
            let errorModel = ErrorModel(errorKey: error.localizedDescription)
            Log(error: errorModel).withDate().make()
            completion(.failure(errorModel))
        }
    }
    
    private func makeResponseModel<T: BaseResponse>(with data: Data) throws -> ResponseModel<T> {
        let responseModel = ResponseModel<T>()
        responseModel.rawData = data
        responseModel.data = try JSONDecoder().decode(T.self, from: data)
        
        return responseModel
    }
    
}
