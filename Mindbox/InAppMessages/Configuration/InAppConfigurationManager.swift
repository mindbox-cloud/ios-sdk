//
//  InAppConfigurationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import QuartzCore
import MindboxLogger

protocol InAppConfigurationDelegate: AnyObject {
    func didPreparedConfiguration()
}

enum EmbeddedPlaceSelection: Equatable {

    case decided(InAppTransitionData?)

    case configUnavailable

    case targetingUnavailable

    var inapp: InAppTransitionData? {
        if case .decided(let inapp) = self { return inapp }
        return nil
    }
}

protocol InAppConfigurationManagerProtocol: AnyObject {
    var delegate: InAppConfigurationDelegate? { get set }

    var hasConfig: Bool { get }

    func prepareConfiguration()
    func handleInapps(event: ApplicationEvent?, _ completion: @escaping (InAppFormData?) -> Void)
    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ completion: @escaping (EmbeddedPlaceSelection, _ processingDuration: TimeInterval, _ sessionEpoch: Int, _ configVersion: ConfigVersion?) -> Void)
    func getShowableInappIds(_ ids: [String], askedBy requesterInappId: String, _ completion: @escaping ([String]) -> Void)
    func getInAppToShowById(_ id: String, params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void)
    func getEmbeddedPlaces(_ completion: @escaping ([String: Set<String>]?) -> Void)
    func resetInappManager()
    func inappInCurrentConfig(withId id: String) -> InApp?
}

class InAppConfigurationManager: InAppConfigurationManagerProtocol {

    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.Mindbox.configurationManager")
    private var configResponse: ConfigResponse?

    private struct ConfigEntry {
        let candidates: ConfigCandidates?
        let sessionEpoch: Int
        let version: ConfigVersion
    }

    // Written only on queue; locked so the main thread can read it synchronously.
    @Locked private var configEntry = ConfigEntry(candidates: nil, sessionEpoch: 0, version: ConfigVersion(number: 0))

    var hasConfig: Bool {
        let entry = configEntry
        return entry.candidates != nil && !isOfAnEarlierSession(entry)
    }

    private static let defaultConfigWaitBudget: TimeInterval = 30

    private let configWaitBudget: TimeInterval

    // On queue only.
    private var configWaiters: [Int: (ConfigCandidates?, _ sessionEpoch: Int, _ version: ConfigVersion) -> Void] = [:]

    private func isOfAnEarlierSession(_ entry: ConfigEntry) -> Bool {
        entry.sessionEpoch < SessionTemporaryStorage.shared.ledger.sessionEpoch
    }

    // On queue only.
    private var nextConfigWaiterToken = 0

    // On queue only.
    private var hasConcludedDownload = false

    private var newestDownload = 0
    private let inAppConfigRepository: InAppConfigurationRepository

    // On queue only: swapped on session expiry while the previous session's answers may still be in flight.
    private var inappMapper: InappMapperProtocol?
    private let inAppConfigAPI: InAppConfigurationAPI
    private let persistenceStorage: PersistenceStorage
    private let featureToggleManager: FeatureToggleManager
    private let webViewPrewarmService: InAppWebViewPrewarmServiceProtocol
    private let inappFilterService: InappFilterProtocol
    private let requestedInappBuilder: RequestedInappBuilder

    private let now: () -> TimeInterval

    private let notificationCenter: NotificationCenter

    init(
        inAppConfigAPI: InAppConfigurationAPI,
        inAppConfigRepository: InAppConfigurationRepository,
        inappMapper: InappMapperProtocol?,
        persistenceStorage: PersistenceStorage,
        featureToggleManager: FeatureToggleManager,
        webViewPrewarmService: InAppWebViewPrewarmServiceProtocol,
        inappFilterService: InappFilterProtocol,
        requestedInappBuilder: RequestedInappBuilder,
        configWaitBudget: TimeInterval = InAppConfigurationManager.defaultConfigWaitBudget,
        now: @escaping () -> TimeInterval = { CACurrentMediaTime() },
        notificationCenter: NotificationCenter = .default
    ) {
        self.inAppConfigRepository = inAppConfigRepository
        self.inappMapper = inappMapper
        self.inAppConfigAPI = inAppConfigAPI
        self.persistenceStorage = persistenceStorage
        self.featureToggleManager = featureToggleManager
        self.webViewPrewarmService = webViewPrewarmService
        self.inappFilterService = inappFilterService
        self.requestedInappBuilder = requestedInappBuilder
        self.configWaitBudget = configWaitBudget
        self.now = now
        self.notificationCenter = notificationCenter
    }

    weak var delegate: InAppConfigurationDelegate?

    func prepareConfiguration() {
        queue.async {
            self.downloadConfig()
        }
    }
    
    func handleInapps(event: ApplicationEvent? = nil, _ completion: @escaping (InAppFormData?) -> Void) {
        queue.async {
            guard let inappMapper = self.inappMapper, let candidates = self.configEntry.candidates else {
                completion(nil)
                return
            }

            inappMapper.handleInapps(event, candidates) { inapp in
                completion(inapp)
            }
        }
    }
    
    func selectInappForPlace(_ place: String,
                             trigger: ApplicationEvent?,
                             _ completion: @escaping (EmbeddedPlaceSelection, _ processingDuration: TimeInterval, _ sessionEpoch: Int, _ configVersion: ConfigVersion?) -> Void) {
        let requestedAt = now()
        awaitConfig("place '\(place)'", givingUpAfter: nil, ofCurrentSession: true) { [weak self] candidates, sessionEpoch, version in
            guard let self = self, let inappMapper = self.inappMapper else {
                completion(.decided(nil), 0, sessionEpoch, nil)
                return
            }

            guard let candidates = candidates else {
                completion(.configUnavailable, self.now() - requestedAt, sessionEpoch, version)
                return
            }

            inappMapper.selectInappForPlace(place, trigger: trigger, candidates) { [now] selection in
                completion(selection, now() - requestedAt, sessionEpoch, version)
            }
        }
    }

    func getShowableInappIds(_ ids: [String], askedBy requesterInappId: String, _ completion: @escaping ([String]) -> Void) {
        let requestedAt = now()
        awaitConfig("a page asking about \(ids.count) in-app(s)", givingUpAfter: configWaitBudget) { [weak self] candidates, _, _ in
            guard let self = self, let inappMapper = self.inappMapper, let candidates = candidates else {
                completion([])
                return
            }

            inappMapper.getShowableInappIds(ids, askedBy: requesterInappId, candidates) { [now] allowed in
                let elapsed = String(format: "%.2f", now() - requestedAt)
                Logger.common(message: "[InAppConfigurationManager] Answered the question of the page of in-app \(requesterInappId) about \(ids.count) in-app(s) in \(elapsed)s: \(allowed.count) allowed",
                              category: .inAppMessages)
                completion(allowed)
            }
        }
    }

    func getInAppToShowById(_ id: String, params: [String: JSONValue], _ completion: @escaping (InAppFormData?) -> Void) {
        awaitConfig("showing in-app \(id)", givingUpAfter: configWaitBudget) { [weak self] candidates, _, _ in
            guard let self = self, let candidates = candidates else {
                completion(nil)
                return
            }

            self.requestedInappBuilder.build(id, params: params, from: candidates, completion)
        }
    }

    func inappInCurrentConfig(withId id: String) -> InApp? {
        configEntry.candidates?.renderable.first { $0.id == id }
    }

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
                    let place = embedded.placeSystemName.map(EmbeddedFormVariant.placeKey)
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

    private func awaitConfig(_ what: String,
                             givingUpAfter cap: TimeInterval?,
                             ofCurrentSession: Bool = false,
                             _ completion: @escaping (ConfigCandidates?, _ sessionEpoch: Int, _ version: ConfigVersion) -> Void) {
        queue.async {
            let entry = self.configEntry
            let isOfAnEarlierSession = ofCurrentSession && self.isOfAnEarlierSession(entry)

            if !isOfAnEarlierSession, let candidates = entry.candidates {
                completion(candidates, entry.sessionEpoch, entry.version)
                return
            }

            if !isOfAnEarlierSession, self.hasConcludedDownload {
                Logger.common(message: "[InAppConfigurationManager] The session's config download already finished with nothing, \(what) gets nothing",
                              level: .error, category: .inAppMessages)
                completion(nil, entry.sessionEpoch, entry.version)
                return
            }

            Logger.common(message: "[InAppConfigurationManager] No config of this session yet, \(what) waits for it",
                          level: .debug, category: .inAppMessages)

            let token = self.nextConfigWaiterToken
            self.nextConfigWaiterToken += 1
            self.configWaiters[token] = completion

            guard let cap else { return }

            self.queue.asyncAfter(deadline: .now() + cap) {
                guard let waiter = self.configWaiters.removeValue(forKey: token) else { return }

                Logger.common(message: "[InAppConfigurationManager] Gave up waiting \(cap)s for a config, \(what) gets nothing",
                              level: .error, category: .inAppMessages)
                let entry = self.configEntry
                waiter(nil, entry.sessionEpoch, entry.version)
            }
        }
    }

    // A fresh config can land on queue first, so one pass of the new session may still run on the previous mapper.
    func resetInappManager() {
        queue.async {
            Logger.common(message: "[InAppConfigurationManager] Reset inappMapper.")
            self.inappMapper = nil
            self.inappMapper = DI.inject(InappMapperProtocol.self)
        }
    }

    // MARK: - Private
    private func downloadConfig() {
        hasConcludedDownload = false
        newestDownload += 1
        let download = newestDownload
        let sessionEpoch = SessionTemporaryStorage.shared.ledger.sessionEpoch
        inAppConfigAPI.fetchConfig(completionQueue: queue) { result in
            guard download == self.newestDownload else {
                Logger.common(message: "[InAppConfigurationManager] A config download a later one superseded concluded — dropping what it brought",
                              category: .inAppMessages)
                return
            }

            self.completeDownloadTask(result, sessionEpoch: sessionEpoch)
        }
    }

    private func completeDownloadTask(_ result: InAppConfigurationAPIResult, sessionEpoch: Int) {
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

        if let settings = configResponse?.settings {
            applySessionStorageSettings(settings)
        }

        let candidates = configResponse.map { inappFilterService.candidates(from: $0) }
        let entry = $configEntry.mutate { entry -> ConfigEntry in
            entry = ConfigEntry(candidates: candidates, sessionEpoch: sessionEpoch, version: entry.version.next)
            return entry
        }
        Logger.common(message: "[InAppConfigurationManager] Config \(entry.version) is ready", category: .inAppMessages)
        hasConcludedDownload = true

        let waiters = configWaiters
        configWaiters = [:]
        waiters.sorted { $0.key < $1.key }.forEach { $0.value(entry.candidates, entry.sessionEpoch, entry.version) }

        if let configResponse {
            webViewPrewarmService.prewarmResources(for: configResponse)
        }
        self.delegate?.didPreparedConfiguration()
        sendNotification(with: configResponse?.settings?.slidingExpiration?.pushTokenKeepalive)
        notificationCenter.post(name: .mobileConfigDownloadConcluded,
                                object: nil,
                                userInfo: [Constants.Notification.configVersion: entry.version])
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
