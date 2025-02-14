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
    func handleInapps(event: ApplicationEvent?, _ completion: @escaping (InAppFormData?) -> Void)
    func resetInappManager()
}

/// Prepares in-apps configation (loads from network, stores in cache, cache invalidation).
/// Also builds domain models on the base of configuration: in-app requests, in-app message models.
class InAppConfigurationManager: InAppConfigurationManagerProtocol {

    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.Mindbox.configurationManager")
    private var configResponse: ConfigResponse?
    private let inAppConfigRepository: InAppConfigurationRepository
    private var inappMapper: InappMapperProtocol?
    private let inAppConfigAPI: InAppConfigurationAPI
    private let persistenceStorage: PersistenceStorage

    init(
        inAppConfigAPI: InAppConfigurationAPI,
        inAppConfigRepository: InAppConfigurationRepository,
        inappMapper: InappMapperProtocol?,
        persistenceStorage: PersistenceStorage
    ) {
        self.inAppConfigRepository = inAppConfigRepository
        self.inappMapper = inappMapper
        self.inAppConfigAPI = inAppConfigAPI
        self.persistenceStorage = persistenceStorage
    }

    weak var delegate: InAppConfigurationDelegate?

    func prepareConfiguration() {
        queue.async {
            self.downloadConfig()
        }
    }
    
    func handleInapps(event: ApplicationEvent? = nil, _ completion: @escaping (InAppFormData?) -> Void) {
        guard let inappMapper = inappMapper, let config = configResponse else {
            completion(nil)
            return
        }
        
        inappMapper.handleInapps(event, config) { inapp in
            completion(inapp)
        }
    }
    
    func resetInappManager() {
        Logger.common(message: "[InAppConfigurationManager] Reset inappMapper.")
        inappMapper = nil
        inappMapper = DI.inject(InappMapperProtocol.self)
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
                let config = try jsonDecoder.decode(ConfigResponse.self, from: data)
                configResponse = config
                saveConfigToCache(data)
                setupSettingsFromConfig(config.settings)
                if let monitoring = config.monitoring, let logsManager = DI.inject(SDKLogsManagerProtocol.self) {
                    logsManager.sendLogs(logs: monitoring.logs.elements)
                }
            } catch {
                applyConfigFromCache()
                Logger.common(message: "Failed to parse downloaded config file. Error: \(error)", level: .error, category: .inAppMessages)
            }

        case .empty:
            configResponse = ConfigResponse()
            inAppConfigRepository.clean()

        case let .error(error):
            applyConfigFromCache()
            Logger.common(message: "Failed to download InApp configuration. Error: \(error.localizedDescription)", level: .error, category: .inAppMessages)
        }
        
        self.delegate?.didPreparedConfiguration()
    }

    private func applyConfigFromCache() {
        guard var cachedConfig = self.fetchConfigFromCache() else {
            Logger.common(message: "Failed to apply configuration from cache: No cached configuration found.")
            return
        }
        
        configResponse = cachedConfig

        let ttlValidationService = createTTLValidationService()
        if ttlValidationService.needResetInapps(config: cachedConfig) {
            cachedConfig.inapps = nil
            Logger.common(message: "[TTL] Resetting in-app due to the expiration of the current configuration.")
        }
    }

    private func fetchConfigFromCache() -> ConfigResponse? {
        guard let data = inAppConfigRepository.fetchConfigFromCache() else {
            Logger.common(message: "Cached Config not exists", level: .debug, category: .inAppMessages)
            return nil
        }
        guard let config = try? jsonDecoder.decode(ConfigResponse.self, from: data) else {
            Logger.common(message: "Failed to parse config file from cache", level: .debug, category: .inAppMessages)
            return nil
        }
        Logger.common(message: "Successfuly parsed config file from cache", level: .debug, category: .inAppMessages)
        return config
    }

    private func saveConfigToCache(_ data: Data) {
        let now = Date()
        persistenceStorage.configDownloadDate = now
        Logger.common(message: "[TTL] Config download date successfully updated to: \(now.asDateTimeWithSeconds).")
        inAppConfigRepository.saveConfigToCache(data)
    }

    private func setupSettingsFromConfig(_ settings: Settings?) {
        guard let settings = settings else {
            return
        }

        if let viewCategory = settings.operations?.viewCategory {
            SessionTemporaryStorage.shared.operationsFromSettings.insert(viewCategory.systemName.lowercased())
        }

        if let viewProduct = settings.operations?.viewProduct {
            SessionTemporaryStorage.shared.operationsFromSettings.insert(viewProduct.systemName.lowercased())
        }
        
        saveConfigSessionToCache(settings.slidingExpiration?.config)
    }

    private func createTTLValidationService() -> TTLValidationProtocol {
        return TTLValidationService(persistenceStorage: self.persistenceStorage)
    }
    
    private func saveConfigSessionToCache(_ config: String?) {
        SessionTemporaryStorage.shared.expiredConfigSession = config
        Logger.common(message: "Saved slidingExpiration.config - \(String(describing: config)) to temporary storage.")
        NotificationCenter.default.post(name: .mobileConfigDownloaded, object: nil)
    }
}
