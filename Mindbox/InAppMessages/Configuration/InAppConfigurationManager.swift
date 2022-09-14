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

/// Prepares in-apps configation (loads from network, stores in cache, cache invalidation).
/// Also builds domain models on the base of configuration: in-app requests, in-app message models.
class InAppConfigurationManager {
    
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
            return InAppFormData(imageUrl: imageUrl)
        }
    }

    // MARK: - Private

    private func downloadConfig() {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            completeDownloadTask(nil, error: error)
            return
        }

        do {
            let route = FetchInAppConfigRoute()
            let builder = URLRequestBuilder(domain: configuration.domain)
            let urlRequest = try builder.asURLRequest(route: route)
            URLSession.shared.dataTask(with: urlRequest) { [self] data, response, error in
                queue.async { self.completeDownloadTask(data, error: error) }
            }
            .resume()
        } catch {
            completeDownloadTask(nil, error: error)
        }
    }

    private func completeDownloadTask(_ data: Data?, error: Error?) {
        guard let data = data else {
            Log("Failed to download config file. Error: \(error?.localizedDescription ?? "" )")
                .category(.inAppMessages).level(.debug).make()
            return
        }
        Log("Successfuly downloaded config file. Size: \(data.count) Bytes")
            .category(.inAppMessages).level(.debug).make()
        do {
            let config = try jsonDecoder.decode(InAppConfigResponse.self, from: data)
            saveConfigToCache(data)
            setConfigPrepared(config)
        } catch {
            Log("Failed to parse downloaded config file. Error: \(error)")
                .category(.inAppMessages).level(.debug).make()
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
    var method: HTTPMethod { .get }

    var path: String { "/inapps/byendpoint/someTestMobileEndpoint.json" }

    var headers: HTTPHeaders? { nil }

    var queryParameters: QueryParameters { .init() }

    var body: Data? { nil }
}
