//
//  InjectionMocks.swift
//  MindboxTests
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

extension MBContainer {
    func registerMocks() -> Self {
        register(UUIDDebugService.self) {
            MockUUIDDebugService()
        }
        
        register(UNAuthorizationStatusProviding.self, scope: .transient) {
            MockUNAuthorizationStatusProvider(status: .authorized)
        }
        
        register(SDKVersionValidator.self) {
            SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
        }
        
        register(PersistenceStorage.self) {
            MockPersistenceStorage()
        }
        
        register(MBDatabaseRepository.self) {
            let databaseLoader = DI.injectOrFail(DataBaseLoader.self)
            let persistentContainer = try! databaseLoader.loadPersistentContainer()
            return try! MockDatabaseRepository(persistentContainer: persistentContainer)
        }
        
        register(ImageDownloadServiceProtocol.self, scope: .container) {
            MockImageDownloadService()
        }
        
        register(NetworkFetcher.self) {
            MockNetworkFetcher()
        }
        
        return self
    }
}
