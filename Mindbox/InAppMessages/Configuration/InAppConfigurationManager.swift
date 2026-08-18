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
    func selectInappForPlace(_ place: String, trigger: ApplicationEvent?, _ completion: @escaping (InAppTransitionData?) -> Void)
    func getRenderableInappIds(_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void)
    func getInAppToShowById(_ id: String, params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void)
    func getEmbeddedPlaces(_ completion: @escaping ([String: Set<String>]?) -> Void)
    func resetInappManager()
}

/// Prepares in-apps configation (loads from network, stores in cache, cache invalidation).
/// Also builds domain models on the base of configuration: in-app requests, in-app message models.
class InAppConfigurationManager: InAppConfigurationManagerProtocol {

    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.Mindbox.configurationManager")
    private var configResponse: ConfigResponse?

    /// Confined to `queue`, like `configResponse`.
    private var configCandidates: ConfigCandidates?

    private static let defaultConfigWaitBudget: TimeInterval = 30

    private let configWaitBudget: TimeInterval

    /// Confined to `queue`, like `configResponse`.
    private var configWaiters: [(ConfigCandidates?) -> Void] = []
    private let inAppConfigRepository: InAppConfigurationRepository

    /// Confined to `queue`, like `configResponse`: swapped on session expiry while the previous
    /// session's answers may still be in flight.
    private var inappMapper: InappMapperProtocol?
    private let inAppConfigAPI: InAppConfigurationAPI
    private let persistenceStorage: PersistenceStorage
    private let featureToggleManager: FeatureToggleManager
    private let webViewPrewarmService: InAppWebViewPrewarmServiceProtocol
    private let inappFilterService: InappFilterProtocol

    init(
        inAppConfigAPI: InAppConfigurationAPI,
        inAppConfigRepository: InAppConfigurationRepository,
        inappMapper: InappMapperProtocol?,
        persistenceStorage: PersistenceStorage,
        featureToggleManager: FeatureToggleManager,
        webViewPrewarmService: InAppWebViewPrewarmServiceProtocol,
        inappFilterService: InappFilterProtocol,
        configWaitBudget: TimeInterval = InAppConfigurationManager.defaultConfigWaitBudget
    ) {
        self.inAppConfigRepository = inAppConfigRepository
        self.inappMapper = inappMapper
        self.inAppConfigAPI = inAppConfigAPI
        self.persistenceStorage = persistenceStorage
        self.featureToggleManager = featureToggleManager
        self.webViewPrewarmService = webViewPrewarmService
        self.inappFilterService = inappFilterService
        self.configWaitBudget = configWaitBudget
    }

    weak var delegate: InAppConfigurationDelegate?

    func prepareConfiguration() {
        queue.async {
            self.downloadConfig()
        }
    }
    
    func handleInapps(event: ApplicationEvent? = nil, _ completion: @escaping (InAppFormData?) -> Void) {
        queue.async {
            guard let inappMapper = self.inappMapper, let candidates = self.configCandidates else {
                completion(nil)
                return
            }

            inappMapper.handleInapps(event, candidates) { inapp in
                completion(inapp)
            }
        }
    }
    
    /// Waits for the first config rather than answering nil early: an early "nothing to show"
    /// collapses the block for the screen's whole life — nothing retries.
    func selectInappForPlace(_ place: String, trigger: ApplicationEvent?, _ completion: @escaping (InAppTransitionData?) -> Void) {
        awaitConfig("place '\(place)'") { [weak self] candidates in
            guard let self = self, let inappMapper = self.inappMapper, let candidates = candidates else {
                completion(nil)
                return
            }

            inappMapper.selectInappForPlace(place, trigger: trigger, candidates, completion)
        }
    }

    func getRenderableInappIds(_ ids: [String], _ completion: @escaping (FeedAnswer) -> Void) {
        awaitConfig("a feed asking about \(ids.count) in-app(s)") { [weak self] candidates in
            guard let self = self, let inappMapper = self.inappMapper, let candidates = candidates else {
                completion(.nothing)
                return
            }

            inappMapper.getRenderableInappIds(ids, candidates, completion)
        }
    }

    func getInAppToShowById(_ id: String, params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) {
        awaitConfig("showing in-app \(id)") { [weak self] candidates in
            guard let self = self, let inappMapper = self.inappMapper, let candidates = candidates else {
                completion(nil)
                return
            }

            inappMapper.getInAppToShowById(id, params: params, candidates, completion)
        }
    }

    /// A raw scan, not the selection: unvalidated variants count in on purpose — the resolve applies
    /// the real filters.
    func getEmbeddedPlaces(_ completion: @escaping ([String: Set<String>]?) -> Void) {
        queue.async {
            guard let config = self.configResponse else {
                completion(nil)
                return
            }

            var places: [String: Set<String>] = [:]
            for inapp in config.inapps?.elements ?? [] {
                let inappPlaces = (inapp.form.variants ?? []).compactMap { variant -> String? in
                    guard case .embedded(let embedded) = variant else { return nil }
                    // Must trim the way the selection trims, or the gate would close on a place
                    // the resolve behind it would serve.
                    let place = embedded.placeSystemName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return place?.isEmpty == false ? place : nil
                }

                guard !inappPlaces.isEmpty else { continue }

                let operations = Self.operationNames(in: inapp.targeting)
                for place in inappPlaces {
                    places[place, default: []].formUnion(operations)
                }
            }
            completion(places)
        }
    }

    /// Must mirror the names the checkers file under `operationInapps`: custom operations by their own
    /// system name, product/category nodes by the system operation the config settings declare.
    private static func operationNames(in targeting: Targeting) -> Set<String> {
        switch targeting {
        case .apiMethodCall(let operation):
            return [operation.systemName.lowercased()]
        case .and(let node):
            return node.nodes.reduce(into: Set()) { $0.formUnion(operationNames(in: $1)) }
        case .or(let node):
            return node.nodes.reduce(into: Set()) { $0.formUnion(operationNames(in: $1)) }
        case .viewProductId, .viewProductSegment:
            return Set([SessionTemporaryStorage.shared.viewProductOperation?.lowercased()].compactMap { $0 })
        case .viewProductCategoryId, .viewProductCategoryIdIn:
            return Set([SessionTemporaryStorage.shared.viewCategoryOperation?.lowercased()].compactMap { $0 })
        case .true, .segment, .city, .region, .country, .visit, .pushEnabled, .unknown:
            return []
        }
    }

    private func awaitConfig(_ what: String, _ completion: @escaping (ConfigCandidates?) -> Void) {
        queue.async {
            if let candidates = self.configCandidates {
                completion(candidates)
                return
            }

            Logger.common(message: "[InAppConfigurationManager] No config yet, \(what) waits for it",
                          level: .debug, category: .inAppMessages)

            var hasAnswered = false
            let answer: (ConfigCandidates?) -> Void = { candidates in
                guard !hasAnswered else { return }

                hasAnswered = true
                completion(candidates)
            }

            self.configWaiters.append(answer)

            self.queue.asyncAfter(deadline: .now() + self.configWaitBudget) {
                guard !hasAnswered else { return }

                Logger.common(message: "[InAppConfigurationManager] Gave up waiting \(self.configWaitBudget)s for a config, \(what) gets nothing",
                              level: .error, category: .inAppMessages)
                answer(nil)
            }
        }
    }

    /// The new session's config download is enqueued after this from the same flow, so the swap
    /// always lands on `queue` before that download completes.
    func resetInappManager() {
        queue.async {
            Logger.common(message: "[InAppConfigurationManager] Reset inappMapper.")
            self.inappMapper = nil
            self.inappMapper = DI.inject(InappMapperProtocol.self)
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
                let config = try jsonDecoder.decode(ConfigResponse.self, from: data)
                configResponse = config
                applyDownloadedConfig(config, rawData: data)
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

        configCandidates = configResponse.map { inappFilterService.candidates(from: $0) }

        let waiters = configWaiters
        configWaiters = []
        waiters.forEach { $0(configCandidates) }

        // Prewarm stage 2: warm what the config's webview in-apps need (or release the
        // warm instance when the config proves there are none).
        if let configResponse {
            webViewPrewarmService.prewarmResources(for: configResponse)
        }
        self.delegate?.didPreparedConfiguration()
        sendNotification(with: configResponse?.settings?.slidingExpiration?.pushTokenKeepalive)
    }

    private func applyDownloadedConfig(_ config: ConfigResponse, rawData: Data) {
        saveConfigToCache(rawData)
        setupSettingsFromConfig(config.settings)
        sendMonitoringLogsIfNeeded(config.monitoring)
    }

    private func sendMonitoringLogsIfNeeded(_ monitoring: Monitoring?) {
        guard let monitoring = monitoring else { return }
        guard let logsManager = DI.inject(SDKLogsManagerProtocol.self) else {
            Logger.common(message: "[SDKLogs] Unable to send monitoring logs: SDKLogsManager is not registered in DI", level: .error, category: .general)
            return
        }
        Logger.common(message: "[SDKLogs] Monitoring config contains \(monitoring.logs.elements.count) log request(s)", level: .debug, category: .general)
        logsManager.sendLogs(logs: monitoring.logs.elements)
    }

    private func applyConfigFromCache() {
        guard var cachedConfig = self.fetchConfigFromCache() else {
            Logger.common(message: "Failed to apply configuration from cache: No cached configuration found.")
            return
        }

        let ttlValidationService = createTTLValidationService()
        if ttlValidationService.needResetInapps(config: cachedConfig) {
            cachedConfig.inapps = nil
            Logger.common(message: "[TTL] Resetting in-app due to the expiration of the current configuration.")
        }
        
        configResponse = cachedConfig
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

        applySessionStorageSettings(settings)
        featureToggleManager.applyFeatureToggles(settings.featureToggles)
        persistOperationsDomain(from: settings.baseAddresses)
        saveConfigSessionToCache(settings.slidingExpiration?.config)
    }

    private func applySessionStorageSettings(_ settings: Settings) {
        let storage = SessionTemporaryStorage.shared

        if let viewCategory = settings.operations?.viewCategory {
            storage.viewCategoryOperation = viewCategory.systemName.lowercased()
        }

        if let viewProduct = settings.operations?.viewProduct {
            storage.viewProductOperation = viewProduct.systemName.lowercased()
        }

        if let inappSettings = settings.inapp {
            storage.inAppSettings = inappSettings
        }
    }

    private func persistOperationsDomain(from baseAddresses: Settings.BaseAddresses?) {
        let current = persistenceStorage.operationsDomainFromConfig
        let raw = baseAddresses?.operations

        switch OperationsDomainConfigPolicy.action(for: raw, currentlyStored: current) {
        case .keep:
            break
        case .clear:
            persistenceStorage.operationsDomainFromConfig = nil
            Logger.common(message: "[OperationsDomain] Cleared — config has no value.", level: .info, category: .inAppMessages)
        case .save(let value):
            persistenceStorage.operationsDomainFromConfig = value
            Logger.common(message: "[OperationsDomain] Updated from config. [Value]: \(value)", level: .info, category: .inAppMessages)
        case .rejected(let value):
            Logger.common(message: "[OperationsDomain] Invalid domain from config — ignored, previous value kept. [Value]: \(value)", level: .error, category: .inAppMessages)
        }
    }

    private func createTTLValidationService() -> TTLValidationProtocol {
        return TTLValidationService(persistenceStorage: self.persistenceStorage)
    }
    
    private func saveConfigSessionToCache(_ config: String?) {
        SessionTemporaryStorage.shared.expiredConfigSession = config
        Logger.common(message: "[InappSessionManager] Saved slidingExpiration.config - \(config ?? "nil") to temporary storage.")
        NotificationCenter.default.post(name: .mobileConfigDownloaded, object: nil)
    }
}

// MARK: - For sending "ApplicationKeepalive" via Config

private extension InAppConfigurationManager {
    
    func sendNotification(with pushToken: String?) {
        guard let pushToken else {
            Logger.common(message: "[Keepalive] Push token is nil. Skip next steps", level: .debug, category: .pushTokenKeepalive)
            return
        }
        
        NotificationCenter.default.post(
            name: .receivedPushTokenKeepaliveFromTheMobileConfig,
            object: nil,
            userInfo: [Constants.Notification.pushTokenKeepalive: pushToken as Any]
        )
    }
}
