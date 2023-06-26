//
//  InAppConfigurationAPI.swift
//  Mindbox
//
//  Created by Максим Казаков on 29.09.2022.
//

import Foundation
import MindboxLogger

enum InAppConfigurationAPIResult {
    case empty
    case data(Data)
    case error(Error)
}

class InAppConfigurationAPI {
    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }

    func fetchConfig(completionQueue: DispatchQueue, completion: @escaping (InAppConfigurationAPIResult) -> Void) {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Invalid domain. Domain is unreachable"
            ))
            Logger.error(error.asLoggerError())
            completion(.error(error))
            return
        }
        do {
            let route = FetchInAppConfigRoute(endpoint: configuration.endpoint)
            let builder = URLRequestBuilder(domain: configuration.domain)
            var urlRequest = try builder.asURLRequest(route: route)
            Logger.network(request: urlRequest)
            urlRequest.cachePolicy = .useProtocolCachePolicy
            URLSession.shared.dataTask(with: urlRequest) { [self] data, response, error in
                completionQueue.async {
                    let result = self.completeDownloadTask(data, response: response, error: error)
                    completion(result)
                }
            }
            .resume()
        } catch {
            Logger.common(message: "Failed to start InApp Config downloading task. Error: \(error.localizedDescription).", level: .error, category: .inAppMessages)
            completion(.error(error))
        }
    }

    // MARK: - Private

    private func completeDownloadTask(_ data: Data?, response: URLResponse?, error: Error?) -> InAppConfigurationAPIResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            let error = MindboxError.connectionError
            Logger.error(error.asLoggerError())
            return .error(error)
        }
        
        Logger.response(data: data, response: response, error: error)

        if httpResponse.statusCode == 404 {
            return .empty
        }
        if let data = data {
            return .data(data)
        }  else if let error = error {
            return .error(error)
        } else {
            let error = MindboxError.invalidResponse(response)
            Logger.error(error.asLoggerError())
            return .error(error)
        }
    }
}


private struct FetchInAppConfigRoute: Route {

    let endpoint: String

    init(endpoint: String) {
        self.endpoint = endpoint
    }

    var method: HTTPMethod { .get }

    var path: String { "/mobile/byendpoint/\(endpoint).json" }

    var headers: HTTPHeaders? { nil }

    var queryParameters: QueryParameters { .init() }

    var body: Data? { nil }
}


