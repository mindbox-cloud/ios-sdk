//
//  MBNetworkFetcher.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit.UIDevice

class MBNetworkFetcher: NetworkFetcher {

    private let persistenceStorage: PersistenceStorage
    
    private let session: URLSession
    
    init(utilitiesFetcher: UtilitiesFetcher, persistenceStorage: PersistenceStorage) {
        let sessionConfiguration: URLSessionConfiguration = .default
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknow"
        let appVersion = utilitiesFetcher.appVerson ?? "unknow"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknow"
        let userAgent: String = "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
        sessionConfiguration.httpAdditionalHeaders = [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": sdkVersion,
            "User-Agent": userAgent,
            "Content-Type": "application/json; charset=utf-8"
        ]
        self.persistenceStorage = persistenceStorage
        self.session = URLSession(configuration: sessionConfiguration)
    }
    
    func requestObject<T: BaseResponse>(route: Route, completion: @escaping Completion<T>) {
        guard let configuration = persistenceStorage.configuration else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: Mindbox.Errors.invalidConfiguration(reason: "Configuration is not set")
            )
            completion(.failure(error))
            return
        }
        let builder = URLRequestBuilder(domain: configuration.domain)
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            #if DEBUG
            Log(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders).withDate().make()
            #endif
            session.dataTask(with: urlRequest) { (data, response, error) in
                #if DEBUG
                Log(data: data, response: response, error: error).withDate().make()
                #endif
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
                    responseModel.route = route
                    completion(.success(responseModel))

                } catch let decodeError {
                    let error: ErrorModel = ErrorModel(
                        errorKey: ErrorKey.parsing.rawValue,
                        rawError: decodeError
                    )
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
    
    func request(route: Route, completion: @escaping ((Result<Void, ErrorModel>) -> Void)) {
        guard let configuration = persistenceStorage.configuration else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: Mindbox.Errors.invalidConfiguration(reason: "Configuration is not set")
            )
            completion(.failure(error))
            return
        }
        let builder = URLRequestBuilder(domain: configuration.domain)
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            #if DEBUG
            Log(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders).withDate().make()
            #endif
            session
                .dataTask(with: urlRequest) { (data, response, error) in
                    #if DEBUG
                    Log(data: data, response: response, error: error).withDate().make()
                    #endif
                    do {
                        if let error = error {
                            throw error
                        }
                        guard let response = response as? HTTPURLResponse else {
                            throw URLError(.unknown)
                        }
                        guard HTTPURLResponseStatusCodeValidator(statusCode: response.statusCode).evaluate() else {
                            throw URLError(.unsupportedURL)
                        }
                        completion(.success(()))
                        
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
                    
                }
                .resume()
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
