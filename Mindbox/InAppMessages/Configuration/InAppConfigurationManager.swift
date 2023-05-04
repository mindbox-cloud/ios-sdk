//
//  InAppConfigurationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

protocol InAppConfigurationDelegate: AnyObject {
    func didPreparedConfiguration()
}

protocol InAppConfigurationManagerProtocol: AnyObject {
    var delegate: InAppConfigurationDelegate? { get set }

    func prepareConfiguration()
    func buildInAppRequest(event: InAppMessageTriggerEvent) -> InAppsCheckRequest?
    func getInAppFormData(by inAppResponse: InAppResponse) -> InAppFormData?
    func recalculateInapps(with event: ApplicationEvent)
}

/// Prepares in-apps configation (loads from network, stores in cache, cache invalidation).
/// Also builds domain models on the base of configuration: in-app requests, in-app message models.
class InAppConfigurationManager: InAppConfigurationManagerProtocol {
    
    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.Mindbox.configurationManager")
    private var configuration: InAppConfig!
    private var rawConfigurationResponse: InAppConfigResponse!
    private let inAppConfigRepository: InAppConfigurationRepository
    private let inAppConfigurationMapper: InAppConfigutationMapper
    private let inAppConfigAPI: InAppConfigurationAPI
    private let logsManager: SDKLogsManagerProtocol
    private let sessionStorage: SessionTemporaryStorage

    init(
        inAppConfigAPI: InAppConfigurationAPI,
        inAppConfigRepository: InAppConfigurationRepository,
        inAppConfigurationMapper: InAppConfigutationMapper,
        logsManager: SDKLogsManagerProtocol,
        sessionStorage: SessionTemporaryStorage
    ) {
        self.inAppConfigRepository = inAppConfigRepository
        self.inAppConfigurationMapper = inAppConfigurationMapper
        self.inAppConfigAPI = inAppConfigAPI
        self.logsManager = logsManager
        self.sessionStorage = sessionStorage
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
                        inAppId: $0.id
                    )
                }
            )
        }
    }

    func getInAppFormData(by inAppResponse: InAppResponse) -> InAppFormData? {
        return queue.sync {
            if let inApps = configuration.inAppsByEvent[inAppResponse.triggerEvent],
               let inApp = inApps.first(where: { $0.id == inAppResponse.inAppToShowId }),
               inApp.formDataVariants.count > 0
            {
                let formData = inApp.formDataVariants[0]
                return InAppFormData(
                    inAppId: inApp.id,
                    image: formData.image,
                    redirectUrl: formData.redirectUrl,
                    intentPayload: formData.intentPayload
                )
            } else {
                return nil
            }
        }
    }
    
    func recalculateInapps(with event: ApplicationEvent) {
        queue.sync {
            guard let rawConfigurationResponse = rawConfigurationResponse else {
                return
            }
            
            setConfigPrepared(rawConfigurationResponse, event: event)
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
                setupSettingsFromConfig(config.settings)
                if let monitoring = config.monitoring {
                    logsManager.sendLogs(logs: monitoring.logs)
                }
            } catch {
                applyConfigFromCache()
                Logger.common(message: "Failed to parse downloaded config file. Error: \(error)", level: .error, category: .inAppMessages)
            }

        case .empty:
            let emptyConfig = InAppConfigResponse.init(inapps: [], monitoring: nil, settings: nil)
            inAppConfigRepository.clean()
            setConfigPrepared(emptyConfig)

        case let .error(error):
            applyConfigFromCache()
            Logger.common(message: "Failed to download InApp configuration. Error: \(error.localizedDescription)", level: .error, category: .inAppMessages)
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
            Logger.common(message: "Cached Config not exists", level: .debug, category: .inAppMessages)
            return nil
        }
        guard let config = try? jsonDecoder.decode(InAppConfigResponse.self, from: data) else {
            Logger.common(message: "Failed to parse config file from cache", level: .debug, category: .inAppMessages)
            return nil
        }
        Logger.common(message: "Successfuly parsed config file from cache", level: .debug, category: .inAppMessages)
        return config
    }

    private func saveConfigToCache(_ data: Data) {
        inAppConfigRepository.saveConfigToCache(data)
    }
    
    private func setConfigPrepared(_ configResponse: InAppConfigResponse, event: ApplicationEvent? = nil) {
        rawConfigurationResponse = configResponse
        inAppConfigurationMapper.mapConfigResponse(event, configResponse, { config in
            self.configuration = config
            var configDump = String()
            dump(self.configuration!, to: &configDump)
            Logger.common(message: "InApps Configuration applied: \n\(configDump)", level: .debug, category: .inAppMessages)
            
            self.delegate?.didPreparedConfiguration()
        })
    }
    
    private func setupSettingsFromConfig(_ settings: InAppConfigResponse.Settings?) {
        guard let settings = settings else {
            return
        }
        
        if let viewCategory = settings.operations?.viewCategory {
            sessionStorage.operationsFromSettings.insert(viewCategory.systemName.lowercased())
        }

        if let viewProduct = settings.operations?.viewProduct {
            sessionStorage.operationsFromSettings.insert(viewProduct.systemName.lowercased())
        }
    }
}
