//
//  InAppConfigurationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol InAppConfigurationDelegate: AnyObject {
    func didPreparedConfiguration()
}

protocol InAppConfigurationManagerProtocol: AnyObject {
    var delegate: InAppConfigurationDelegate? { get set }

    func prepareConfiguration()

    func buildInAppRequest(event: InAppMessageTriggerEvent) -> InAppsCheckRequest?

    func getInAppFormData(by inAppResponse: InAppResponse) -> InAppFormData?
}

/// Prepares in-apps configation (loads from network, stores in cache, cache invalidation).
/// Also builds domain models on the base of configuration: in-app requests, in-app message models.
class InAppConfigurationManager: InAppConfigurationManagerProtocol {
    
    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.Mindbox.configurationManager")
    private var configuration: InAppConfig!
    private let inAppConfigRepository: InAppConfigurationRepository
    private let inAppConfigurationMapper: InAppConfigutationMapper
    private let persistenceStorage: PersistenceStorage

    init(
        persistenceStorage: PersistenceStorage,
        inAppConfigRepository: InAppConfigurationRepository,
        inAppConfigurationMapper: InAppConfigutationMapper
    ) {
        self.inAppConfigRepository = inAppConfigRepository
        self.inAppConfigurationMapper = inAppConfigurationMapper
        self.persistenceStorage = persistenceStorage
    }

    weak var delegate: InAppConfigurationDelegate?

    func prepareConfiguration() {
        queue.async {
            if let config = self.fetchConfigFromCache() {
                self.setConfigPrepared(config)
            } else {
                self.downloadConfig()
            }
        }
    }

    func buildInAppRequest(event: InAppMessageTriggerEvent) -> InAppsCheckRequest? {
        queue.sync {
            guard let configuration = configuration,
                  let inAppInfos = configuration.inAppsByEvent[event],
                  !inAppInfos.isEmpty
            else { return nil }

            return InAppsCheckRequest(
                triggerEvent: event,
                possibleInApps: inAppInfos.map {
                    InAppsCheckRequest.InAppInfo(
                        inAppId: $0.id,
                        targeting: $0.targeting
                    )
                }
            )
        }
    }

    func getInAppFormData(by inAppResponse: InAppResponse) -> InAppFormData? {
        queue.sync {
            guard let inApps = configuration.inAppsByEvent[inAppResponse.triggerEvent],
                  let inApp = inApps.first(where: { $0.id == inAppResponse.inAppToShowId }),
                  inApp.formDataVariants.count > 0
            else {
                return nil
            }
            let formData = inApp.formDataVariants[0]
            guard let imageUrl = URL(string: formData.imageUrl) else {
                return nil
            }
            return InAppFormData(imageUrl: imageUrl, redirectUrl: formData.redirectUrl, intentPayload: formData.intentPayload)
        }
    }

    // MARK: - Private

    private func downloadConfig() {
        guard let configuration = persistenceStorage.configuration else {
            Log("SDK configuration should be ready before downloading InApp config.")
                .category(.inAppMessages).level(.error).make()
            return
        }
        do {
            let route = FetchInAppConfigRoute(endpoint: configuration.endpoint)
            let builder = URLRequestBuilder(domain: configuration.domain)
            let urlRequest = try builder.asURLRequest(route: route)
            URLSession.shared.dataTask(with: urlRequest) { [self] data, response, error in
                queue.async { self.completeDownloadTask(data, response: response, error: error) }
            }
            .resume()
        } catch {
            Log("Failed to start InApp Config downloading task. Error: \(error.localizedDescription).")
                .category(.inAppMessages).level(.error).make()
        }
    }

    // Handles download result. Only print logs when failed: consider adding retry logic in future
    private func completeDownloadTask(_ data: Data?, response: URLResponse?, error: Error?) {
        guard let httpResponse = response as? HTTPURLResponse else {
            Log("Downloading InApp Config: invalid response.")
                .category(.inAppMessages).level(.error).make()
            return
        }

        if httpResponse.statusCode == 404 {
            // This is regular situation when in-app configuration is not setup on server
            Log("InApp Config is not setup on server.")
                .category(.inAppMessages).level(.info).make()
            return
        }

        guard let data = data else {
            Log("Failed to download config file. Http code: \(httpResponse.statusCode). Error: \(error?.localizedDescription ?? "" )")
                .category(.inAppMessages).level(.error).make()
            return
        }

        Log("Successfuly downloaded config file. Size: \(data.count) Bytes")
            .category(.inAppMessages).level(.info).make()
        do {
            let config = try jsonDecoder.decode(InAppConfigResponse.self, from: data)
            saveConfigToCache(data)
            setConfigPrepared(config)
            Log("Successfuly parsed config file\n \(config)")
                .category(.inAppMessages).level(.info).make()
        } catch {
            Log("Failed to parse downloaded config file. Error: \(error)")
                .category(.inAppMessages).level(.error).make()
        }
    }

    private func fetchConfigFromCache() -> InAppConfigResponse? {
        guard let data = inAppConfigRepository.fetchConfigFromCache() else {
            return nil
        }
        guard let config = try? jsonDecoder.decode(InAppConfigResponse.self, from: data) else {
            Log("Failed to parse config file")
                .category(.inAppMessages).level(.debug).make()
            return nil
        }
        Log("Successfuly parsed config file")
            .category(.inAppMessages).level(.debug).make()
        return config
    }

    private func saveConfigToCache(_ data: Data) {
        inAppConfigRepository.saveConfigToCache(data)
    }

    private func setConfigPrepared(_ configResponse: InAppConfigResponse) {
        configuration = inAppConfigurationMapper.mapConfigResponse(configResponse)
        delegate?.didPreparedConfiguration()
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
