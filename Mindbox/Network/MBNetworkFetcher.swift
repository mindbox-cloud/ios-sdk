//
//  MBNetworkFetcher.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit.UIDevice
import MindboxLogger

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
        session = URLSession(configuration: sessionConfiguration)
    }

    func request<T>(
        type: T.Type,
        route: Route,
        needBaseResponse: Bool = true,
        completion: @escaping (Result<T, MindboxError>) -> Void
    ) where T: Decodable {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            Logger.error(error)
            completion(.failure(error))
            return
        }
        
        let builder = URLRequestBuilder(domain: configuration.domain)
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            Logger.network(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders)
            // Starting data task
            session.dataTask(with: urlRequest) { data, response, error in
                self.handleResponse(data, response, error, needBaseResponse: needBaseResponse) { result in
                    switch result {
                    case let .success(response):
                        do {
                            let decoder = JSONDecoder()
                            let object = try decoder.decode(type, from: response)
                            completion(.success(object))
                        } catch {
                            let errorModel: MindboxError = .internalError(.init(errorKey: .parsing, rawError: error))
                            Logger.error(errorModel)
                            completion(.failure(errorModel))
                        }
                    case let .failure(error):
                        Logger.error(error)
                        completion(.failure(error))
                    }
                }
            }.resume()
        } catch let error {
            let errorModel = MindboxError.unknown(error)
            Logger.error(errorModel)
            completion(.failure(errorModel))
        }
    }

    func request(
        route: Route,
        completion: @escaping ((Result<Void, MindboxError>) -> Void)
    ) {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            Logger.error(error)
            completion(.failure(error))
            return
        }
        let builder = URLRequestBuilder(domain: configuration.domain)
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            Logger.network(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders)
            // Starting data task
            session.dataTask(with: urlRequest) { [weak self] data, response, error in
                self?.handleResponse(data, response, error, emptyData: true, completion: { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case let .failure(error):
                        Logger.error(error)
                        completion(.failure(error))
                    }
                })
            }.resume()
        } catch let error {
            let errorModel = MindboxError.unknown(error)
            Logger.error(errorModel)
            completion(.failure(errorModel))
        }
    }

    private func handleResponse(
        _ data: Data?,
        _ response: URLResponse?,
        _ error: Error?,
        emptyData: Bool = false,
        needBaseResponse: Bool = false,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        Logger.response(data: data, response: response, error: error)
        
        // Check if we have any response at all
        guard let response = response else {
            completion(.failure(.connectionError))
            return
        }

        // Make sure we got the correct response type
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.invalidResponse(response)))
            return
        }

        // Make sure response has status code
        guard let statusCode = HTTPURLResponseStatusCodeValidator.StatusCodes(statusCode: httpResponse.statusCode) else {
            if error != nil {
                completion(.failure(.serverError(.init(status: .internalServerError, errorMessage: "Unknown status code", httpStatusCode: httpResponse.statusCode))))
            } else {
                completion(.failure(.invalidResponse(response)))
            }
            return
        }

        let decoder = JSONDecoder()

        // Trying to handle data if exist
        if let data = data {
            do {
                if needBaseResponse {
                    // Decoding to structure with `status` field
                    let base = try decoder.decode(BaseResponse.self, from: data)
                    // Figure out what server returned
                    switch base.status {
                    case .success, .transactionAlreadyProcessed:
                        completion(.success(data))
                    case .validationError:
                        let error = try decoder.decode(ValidationError.self, from: data)
                        completion(.failure(.validationError(error)))
                    case .protocolError:
                        let error = try decoder.decode(ProtocolError.self, from: data)
                        completion(.failure(.protocolError(error)))
                    case .internalServerError:
                        let error = try decoder.decode(ProtocolError.self, from: data)
                        completion(.failure(.serverError(error)))
                    case .unknown:
                        completion(.failure(.invalidResponse(response)))
                    }
                } else {
                    completion(.success(data))
                }
            } catch let decodingError {
                switch statusCode {
                case .serverError:
                    completion(.failure(.serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: httpResponse.statusCode))))
                default:
                     if emptyData {
                        completion(.success(data))
                    } else if httpResponse.statusCode == 404 {
                        completion(.failure(.protocolError(.init(status: .protocolError, errorMessage: "Invalid request url", httpStatusCode: httpResponse.statusCode))))
                    } else {
                        completion(.failure(.internalError(.init(errorKey: .parsing, rawError: decodingError))))
                    }
                }
            }
        } else if let error = error {
            // Handle server errors
            switch statusCode {
            case .serverError:
                completion(.failure(.serverError(.init(status: .internalServerError, errorMessage: "Internal Server error", httpStatusCode: httpResponse.statusCode))))
            default:
                completion(.failure(.unknown(error)))
            }
        } else {
            completion(.failure(.invalidResponse(response)))
        }
    }
}
