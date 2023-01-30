//
//  InAppConfigurationAPI.swift
//  Mindbox
//
//  Created by Максим Казаков on 29.09.2022.
//

import Foundation

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
            let errorModel = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Invalid domain. Domain is unreachable"
            ))
            Logger.error(errorModel)
            completion(.error(errorModel))
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
            Log("Failed to start InApp Config downloading task. Error: \(error.localizedDescription).")
                .category(.inAppMessages).level(.error).make()
            completion(.error(error))
        }
    }

    // MARK: - Private

    private func completeDownloadTask(_ data: Data?, response: URLResponse?, error: Error?) -> InAppConfigurationAPIResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            let errorModel = MindboxError.connectionError
            Logger.error(errorModel)
            return .error(errorModel)
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
            let errorModel = MindboxError.invalidResponse(response)
            Logger.error(errorModel)
            return .error(errorModel)
        }
    }
}


private struct FetchInAppConfigRoute: Route {

    let endpoint: String

    init(endpoint: String) {
        self.endpoint = endpoint
    }

    var method: HTTPMethod { .get }

    var path: String { "/inapps/byendpoint/\(endpoint).json" }

    var headers: HTTPHeaders? { nil }

    var queryParameters: QueryParameters { .init() }

    var body: Data? { nil }
}


