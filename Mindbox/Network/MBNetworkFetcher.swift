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
        self.persistenceStorage = persistenceStorage
        session = MBNetworkFetcher.makeSession(utilitiesFetcher: utilitiesFetcher)
    }

    init(persistenceStorage: PersistenceStorage, session: URLSession) {
        self.persistenceStorage = persistenceStorage
        self.session = session
    }

    private static func makeSession(utilitiesFetcher: UtilitiesFetcher) -> URLSession {
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
        return URLSession(configuration: sessionConfiguration)
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
            Logger.error(error.asLoggerError())
            completion(.failure(error))
            return
        }

        let builder = URLRequestBuilder(
            domain: configuration.domain,
            operationsDomain: resolvedOperationsDomain(configuration: configuration)
        )
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            Logger.network(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders)
            // Starting data task
            let startTime = CFAbsoluteTimeGetCurrent()
            session.dataTask(with: urlRequest) { data, response, error in
                let networkTimeMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                self.handleResponse(data, response, error, needBaseResponse: needBaseResponse, networkTimeMs: networkTimeMs) { result in
                    switch result {
                    case let .success(response):
                        do {
                            let decoder = JSONDecoder()
                            let object = try decoder.decode(type, from: response)
                            completion(.success(object))
                        } catch {
                            let errorModel: MindboxError = .internalError(.init(errorKey: .parsing, rawError: error))
                            Logger.error(errorModel.asLoggerError())
                            completion(.failure(errorModel))
                        }
                    case let .failure(error):
                        Logger.error(error.asLoggerError())
                        completion(.failure(error))
                    }
                }
            }.resume()
        } catch let error {
            let error = MindboxError.unknown(error)
            Logger.error(error.asLoggerError())
            completion(.failure(error))
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
            Logger.error(error.asLoggerError())
            completion(.failure(error))
            return
        }
        let builder = URLRequestBuilder(
            domain: configuration.domain,
            operationsDomain: resolvedOperationsDomain(configuration: configuration)
        )
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            Logger.network(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders)
            // Starting data task
            let startTime = CFAbsoluteTimeGetCurrent()
            session.dataTask(with: urlRequest) { [weak self] data, response, error in
                let networkTimeMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                self?.handleResponse(data, response, error, emptyData: true, needBaseResponse: true, networkTimeMs: networkTimeMs, completion: { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case let .failure(error):
                        Logger.error(error.asLoggerError())
                        completion(.failure(error))
                    }
                })
            }.resume()
        } catch let error {
            let errorModel = MindboxError.unknown(error)
            Logger.error(errorModel.asLoggerError())
            completion(.failure(errorModel))
        }
    }

    func requestRaw(
        route: Route,
        completion: @escaping (Result<Data, MindboxError>) -> Void
    ) {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            Logger.error(error.asLoggerError())
            completion(.failure(error))
            return
        }

        let builder = URLRequestBuilder(
            domain: configuration.domain,
            operationsDomain: resolvedOperationsDomain(configuration: configuration)
        )
        do {
            let urlRequest = try builder.asURLRequest(route: route)
            Logger.network(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders)
            let startTime = CFAbsoluteTimeGetCurrent()
            session.dataTask(with: urlRequest) { data, response, error in
                let networkTimeMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                self.handleResponse(data, response, error, needBaseResponse: false, networkTimeMs: networkTimeMs) { result in
                    switch result {
                    case let .success(data):
                        completion(.success(data))
                    case let .failure(error):
                        Logger.error(error.asLoggerError())
                        completion(.failure(error))
                    }
                }
            }.resume()
        } catch let error {
            let errorModel = MindboxError.unknown(error)
            Logger.error(errorModel.asLoggerError())
            completion(.failure(errorModel))
        }
    }

    private func handleResponse(
        _ data: Data?,
        _ response: URLResponse?,
        _ error: Error?,
        emptyData: Bool = false,
        needBaseResponse: Bool = false,
        networkTimeMs: Int = 0,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        Logger.response(data: data, response: response, error: error)

        guard let responseContext = makeResponseContext(response: response, error: error, networkTimeMs: networkTimeMs, completion: completion) else {
            return
        }

        if let data = data {
            handleResponseData(
                data,
                context: responseContext,
                emptyData: emptyData,
                needBaseResponse: needBaseResponse,
                completion: completion
            )
            return
        }

        handleMissingData(
            error: error,
            context: responseContext,
            completion: completion
        )
    }

    private struct ResponseContext {
        let response: URLResponse
        let httpResponse: HTTPURLResponse
        let statusCode: HTTPURLResponseStatusCodeValidator.StatusCodes
        let networkTimeMs: Int
    }

    private func makeResponseContext(
        response: URLResponse?,
        error: Error?,
        networkTimeMs: Int,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) -> ResponseContext? {
        guard let response = response else {
            completion(.failure(.connectionError))
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.invalidResponse(response)))
            return nil
        }

        guard let statusCode = HTTPURLResponseStatusCodeValidator.StatusCodes(statusCode: httpResponse.statusCode) else {
            if error != nil {
                completion(.failure(.serverError(.init(
                    status: .internalServerError,
                    errorMessage: "Unknown status code",
                    httpStatusCode: httpResponse.statusCode
                ))))
            } else {
                completion(.failure(.invalidResponse(response)))
            }
            return nil
        }

        return ResponseContext(
            response: response,
            httpResponse: httpResponse,
            statusCode: statusCode,
            networkTimeMs: networkTimeMs
        )
    }

    private func handleResponseData(
        _ data: Data,
        context: ResponseContext,
        emptyData: Bool,
        needBaseResponse: Bool,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        switch context.statusCode {
        case .success:
            handleSuccessResponseData(
                data,
                context: context,
                emptyData: emptyData,
                needBaseResponse: needBaseResponse,
                completion: completion
            )
        case .clientError:
            handleClientErrorResponseData(
                data,
                context: context,
                completion: completion
            )
        case .serverError:
            handleServerErrorResponseData(
                data,
                context: context,
                completion: completion
            )
        case .redirection:
            completion(.failure(.invalidResponse(context.response)))
        }
    }

    // MARK: - 2xx Success

    private func handleSuccessResponseData(
        _ data: Data,
        context: ResponseContext,
        emptyData: Bool,
        needBaseResponse: Bool,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        if !needBaseResponse {
            completion(.success(data))
            return
        }

        let decoder = JSONDecoder()
        do {
            let base = try decoder.decode(BaseResponse.self, from: data)
            switch base.status {
            case .success, .transactionAlreadyProcessed:
                completion(.success(data))
            case .validationError:
                let error = try decoder.decode(ValidationError.self, from: data)
                completion(.failure(.validationError(error)))
            case .protocolError, .internalServerError, .unknown:
                completion(.failure(.invalidResponse(context.response)))
            }
        } catch {
            if emptyData {
                completion(.success(data))
            } else {
                completion(.failure(.internalError(.init(errorKey: .parsing, rawError: error))))
            }
        }
    }

    // MARK: - 4xx Client Error

    private func handleClientErrorResponseData(
        _ data: Data,
        context: ResponseContext,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        let httpCode = context.httpResponse.statusCode
        let decoder = JSONDecoder()

        do {
            let base = try decoder.decode(BaseResponse.self, from: data)
            switch base.status {
            case .protocolError:
                let error = try decoder.decode(ProtocolError.self, from: data)
                completion(.failure(.protocolError(error)))
            case .validationError:
                let error = try decoder.decode(ValidationError.self, from: data)
                completion(.failure(.validationError(error)))
            default:
                completion(.failure(.protocolError(.init(
                    status: .protocolError,
                    errorMessage: "Client error",
                    httpStatusCode: httpCode
                ))))
            }
        } catch {
            if httpCode == 404 {
                completion(.failure(.protocolError(.init(
                    status: .protocolError,
                    errorMessage: "Invalid request url",
                    httpStatusCode: httpCode
                ))))
            } else {
                completion(.failure(.protocolError(.init(
                    status: .protocolError,
                    errorMessage: "Client error",
                    httpStatusCode: httpCode
                ))))
            }
        }
    }

    // MARK: - 5xx Server Error

    private func handleServerErrorResponseData(
        _ data: Data,
        context: ResponseContext,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        let decoder = JSONDecoder()
        do {
            let error = try decoder.decode(ProtocolError.self, from: data)
            completion(.failure(.serverError(error)))
        } catch {
            let body = String(data: data, encoding: .utf8)
            completion(.failure(internalServerError(
                httpStatusCode: context.httpResponse.statusCode,
                networkTimeMs: context.networkTimeMs,
                responseBody: body
            )))
        }
    }

    private func handleMissingData(
        error: Error?,
        context: ResponseContext,
        completion: @escaping ((Result<Data, MindboxError>) -> Void)
    ) {
        if let error = error {
            switch context.statusCode {
            case .serverError:
                completion(.failure(internalServerError(httpStatusCode: context.httpResponse.statusCode, networkTimeMs: context.networkTimeMs)))
            default:
                completion(.failure(.unknown(error)))
            }
        } else {
            completion(.failure(.invalidResponse(context.response)))
        }
    }

    private func internalServerError(httpStatusCode: Int, networkTimeMs: Int = 0, responseBody: String? = nil) -> MindboxError {
        let body = responseBody ?? "{}"
        return .serverError(.init(
            status: .internalServerError,
            errorMessage: "MindboxError.serverError. statusCode=\(httpStatusCode), networkTimeMs=\(networkTimeMs), body=\(body)",
            httpStatusCode: httpStatusCode
        ))
    }
    
    /// Cancels all ongoing network tasks started by this fetcher.
    func cancelAllTasks() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    private func resolvedOperationsDomain(configuration: MBConfiguration) -> String? {
        Self.resolveOperationsDomain(
            fromConfigJSON: persistenceStorage.operationsDomainFromConfig,
            fromInit: configuration.operationsDomain
        )
    }

    /// Priority: JSON config > init > nil. Empty strings count as "no value".
    /// Static for unit-testing without a PersistenceStorage or MBConfiguration.
    static func resolveOperationsDomain(fromConfigJSON: String?, fromInit: String?) -> String? {
        if let fromConfig = fromConfigJSON, !fromConfig.isEmpty {
            return fromConfig
        }
        if let fromInit = fromInit, !fromInit.isEmpty {
            return fromInit
        }
        return nil
    }
}
