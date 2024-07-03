//
//  InjectReplaceable.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit

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
            let defaults = UserDefaults(suiteName: utilitiesFetcher.applicationGroupIdentifier)!
            return MBPersistenceStorage(defaults: defaults)
        }
        
        register(MBDatabaseRepository.self) {
            let databaseLoader = DI.injectOrFail(DataBaseLoader.self)
            let persistentContainer = try! databaseLoader.loadPersistentContainer()
            return try! MBDatabaseRepository(persistentContainer: persistentContainer)
        }
        
        register(ImageDownloadServiceProtocol.self, scope: .container) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let imageDownloader = URLSessionImageDownloader(persistenceStorage: persistenceStorage)
            return ImageDownloadService(imageDownloader: imageDownloader)
        }
        
        return self
    }
}
