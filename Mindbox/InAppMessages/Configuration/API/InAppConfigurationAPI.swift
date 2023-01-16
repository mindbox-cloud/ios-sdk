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

struct InAppGeoResponse: Codable {
    let city: Int
    let region: Int
    let country: Int
    
    enum CodingKeys: String, CodingKey {
        case city = "city_id"
        case region = "region_id"
        case country = "country_id"
    }
}

class InAppConfigurationAPI {
    private let persistenceStorage: PersistenceStorage

    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    func fetchGeo(completionQueue: DispatchQueue, completion: @escaping (InAppGeoResponse?) -> Void) {
        guard let configuration = persistenceStorage.configuration else {
            completion(nil)
            return
        }
        
        do {
            let route = FetchInAppGeoRoute(endpoint: configuration.endpoint)
            let builder = URLRequestBuilder(domain: configuration.domain)
            var urlRequest = try builder.asURLRequest(route: route)
            urlRequest.cachePolicy = .useProtocolCachePolicy
            URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                completionQueue.async {
                    if let data = data,
                        let decodedResponse = try? JSONDecoder().decode(InAppGeoResponse.self, from: data) {
                        completion(decodedResponse)
                    } else {
                        completion(nil)
                    }
                }
            }
            .resume()
        } catch {
            Log("Failed to download InApp Geo Data. Error: \(error.localizedDescription).")
                .category(.inAppMessages).level(.error).make()
            completion(nil)
        }
    }

    func fetchConfig(completionQueue: DispatchQueue, completion: @escaping (InAppConfigurationAPIResult) -> Void) {
        guard let configuration = persistenceStorage.configuration else {
            completion(.error(MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Invalid domain. Domain is unreachable"
            ))))
            return
        }
        do {
            let route = FetchInAppConfigRoute(endpoint: configuration.endpoint)
            let builder = URLRequestBuilder(domain: configuration.domain)
            var urlRequest = try builder.asURLRequest(route: route)
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
            return .error(MindboxError.connectionError)
        }
        Log("Config response. Code: \(httpResponse.statusCode). Has data: \(data != nil), Error: \(error?.localizedDescription ?? "").")
            .category(.inAppMessages).level(.error).make()
        if httpResponse.statusCode == 404 {
            return .empty
        }
        if let data = data {
            return .data(data)
        }  else if let error = error {
            return .error(error)
        } else {
            return .error(MindboxError.invalidResponse(response))
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


private struct FetchInAppGeoRoute: Route {

    let endpoint: String

    init(endpoint: String) {
        self.endpoint = endpoint
    }

    var method: HTTPMethod { .get }

    var path: String { "/geo" }

    var headers: HTTPHeaders? { nil }

    var queryParameters: QueryParameters { .init() }

    var body: Data? { nil }
}
