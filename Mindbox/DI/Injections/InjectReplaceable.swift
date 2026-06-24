//
//  InjectReplaceable.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

extension MBContainer {
    func registerReplaceableUtilities() -> Self {
        register(UUIDDebugService.self) {
            PasteboardUUIDDebugService(
                notificationCenter: NotificationCenter.default,
                currentDateProvider: { return Date() },
                pasteboard: UIPasteboard.general
            )
        }

        register(UNAuthorizationStatusProviding.self, scope: .transient) {
            UNAuthorizationStatusProvider()
        }

        register(SDKVersionValidator.self) {
            SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
        }

        register(PersistenceStorage.self) {
            let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
            let appGroup = utilitiesFetcher.applicationGroupIdentifier

            guard !appGroup.isEmpty else {
                // App Group unavailable (already reported by the fetcher) — fall back to
                // local defaults so the SDK keeps working without the shared suite instead
                // of crashing the host (issue #705).
                //
                // Broken→fixed transition (future reference): while the group is missing,
                // install identity (deviceUUID, installationDate, …) is written to
                // `.standard`. If the integrator later fixes the App Group, the now-used
                // suite is empty, so the SDK sees `isInstalled == false` and re-registers
                // the install. deviceUUID is re-derived from IDFV and stays stable on the
                // same device (no duplicate device), but a fresh install event is sent and
                // local state (in-app caps, counters) resets. This is accepted rather than
                // migrating `.standard`→suite; a one-shot carry-over could be added later
                // if re-registration churn becomes a problem.
                return MBPersistenceStorage(defaults: .standard)
            }

            guard let defaults = UserDefaults(suiteName: appGroup) else {
                // Unreachable for a resolved App Group id; degrade without trapping (issue #705).
                Logger.common(message: "[PersistenceStorage] UserDefaults(suiteName: \(appGroup)) failed; using .standard.", level: .fault, category: .general)
                return MBPersistenceStorage(defaults: .standard)
            }

            return MBPersistenceStorage(defaults: defaults)
        }

        register(WebViewLocalStateStorageProtocol.self, scope: .transient) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return WebViewLocalStateStorage(persistenceStorage: persistenceStorage)
        }

        register(HapticServiceProtocol.self, scope: .transient) {
            HapticService()
        }

        register(MotionServiceProtocol.self, scope: .transient) {
            MotionService()
        }

        register(PermissionHandlerRegistryProtocol.self, scope: .transient) {
            let registry = PermissionHandlerRegistry()
            registry.register(PushNotificationsPermissionHandler())
            return registry
        }

        register(DatabaseRepositoryProtocol.self) {
            let loader = DI.injectOrFail(DatabaseLoaderProtocol.self)

            do {
                let container = try loader.loadPersistentContainer()
                return try MBDatabaseRepository(persistentContainer: container)
            } catch {
                assertionFailure("Failed to create MBDatabaseRepository: \(error)")
                return NoopDatabaseRepository()
            }
        }

        register(ImageDownloadServiceProtocol.self, scope: .container) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let imageDownloader = URLSessionImageDownloader(persistenceStorage: persistenceStorage)
            return ImageDownloadService(imageDownloader: imageDownloader)
        }

        register(NetworkFetcher.self) {
            let utilitiesFetcher = DI.injectOrFail(UtilitiesFetcher.self)
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            return MBNetworkFetcher(utilitiesFetcher: utilitiesFetcher, persistenceStorage: persistenceStorage)
        }

        register(InAppConfigurationDataFacadeProtocol.self, scope: .transient) {
            let segmentationSevice = DI.injectOrFail(SegmentationServiceProtocol.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            let imageService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)
            let failureManager = DI.injectOrFail(InappShowFailureManagerProtocol.self)

            return InAppConfigurationDataFacade(segmentationService: segmentationSevice,
                                                targetingChecker: targetingChecker,
                                                imageService: imageService,
                                                tracker: tracker,
                                                failureManager: failureManager)
        }

        register(SessionManager.self) {
            let trackVisitManager = DI.injectOrFail(TrackVisitManagerProtocol.self)
            return MBSessionManager(trackVisitManager: trackVisitManager)
        }

        register(SDKLogsManagerProtocol.self, scope: .transient) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let eventRepository = DI.injectOrFail(EventRepository.self)
            return SDKLogsManager(persistenceStorage: persistenceStorage, eventRepository: eventRepository)
        }

        register(InAppCoreManagerProtocol.self) {
            let configManager = DI.injectOrFail(InAppConfigurationManagerProtocol.self)
            let inappScheduler = DI.injectOrFail(InappScheduleManagerProtocol.self)
            
            return InAppCoreManager(configManager: configManager, inappScheduler: inappScheduler)
        }

        return self
    }
}
