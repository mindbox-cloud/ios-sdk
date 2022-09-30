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
    private let inAppConfigAPI: InAppConfigurationAPI

    init(
        inAppConfigAPI: InAppConfigurationAPI,
        inAppConfigRepository: InAppConfigurationRepository,
        inAppConfigurationMapper: InAppConfigutationMapper
    ) {
        self.inAppConfigRepository = inAppConfigRepository
        self.inAppConfigurationMapper = inAppConfigurationMapper
        self.inAppConfigAPI = inAppConfigAPI
    }

    weak var delegate: InAppConfigurationDelegate?

    func prepareConfiguration() {
        queue.async {
            self.downloadConfig()
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
        inAppConfigAPI.fetchConfig(completionQueue: queue) { result in
            self.completeDownloadTask(result)
        }
    }

    private func completeDownloadTask(_ result: InAppConfigurationAPIResult) {
        switch result {
        case let .data(data):
            do {
                let config = try jsonDecoder.decode(InAppConfigResponse.self, from: data)
                saveConfigToCache(data)
                setConfigPrepared(config)
            } catch {
                applyConfigFromCache()
                Log("Failed to parse downloaded config file. Error: \(error)")
                    .category(.inAppMessages).level(.error).make()
            }

        case .empty:
            inAppConfigRepository.clean()
            setConfigPrepared(.init(inapps: []))

        case let .error(error):
            applyConfigFromCache()
            Log("Failed to download InApp configuration. Error: \(error.localizedDescription)")
                .category(.inAppMessages).level(.error).make()
        }
    }

    private func applyConfigFromCache() {
        guard let cachedConfig = self.fetchConfigFromCache() else {
            return
        }
        setConfigPrepared(cachedConfig)
    }

    private func fetchConfigFromCache() -> InAppConfigResponse? {
        guard let data = inAppConfigRepository.fetchConfigFromCache() else {
            return nil
        }
        guard let config = try? jsonDecoder.decode(InAppConfigResponse.self, from: data) else {
            Log("Failed to parse config file from cache")
                .category(.inAppMessages).level(.debug).make()
            return nil
        }
        Log("Successfuly parsed config file from cache")
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
