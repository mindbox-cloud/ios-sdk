//
//  DIManager.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

/// Регистрирует DI-объекты
final class DIManager: NSObject {
    
    static let shared: DIManager = DIManager()

    private(set) var container: Odin  = Odin()

    override private init() {
        super.init()
    }
    
    private var appGroup: String? {
        let utilitiesFetcher: UtilitiesFetcher = self.container.resolveOrDie()
        guard let hostApplicationName = utilitiesFetcher.hostApplicationName else {
            return nil
        }
        let identifier = "group.cloud.MindBox.\(hostApplicationName)"
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil ? identifier : nil
    }

    var atOnce = true
    func registerServices() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {

            if atOnce {
                atOnce = false
            } else {
                return
            }

        }
        #endif
        defer {
            Log("❇️Dependency container registration is complete.")
                .inChanel(.system)
                .withMeta()
                .withDate()
                .make()
        }


        container.registerInContainer { (r) -> ConfigurationStorage in
            MBConfigurationStorage()
        }

        container.register { (r) -> UtilitiesFetcher in
            MBUtilitiesFetcher()
        }
        
        container.registerInContainer { [weak self] (r) -> PersistenceStorage in
            if let appGroup = self?.appGroup {
                return MBPersistenceStorage(defaults: UserDefaults(suiteName: appGroup) ?? .standard)
            } else {
                return MBPersistenceStorage(defaults: .standard)
            }
        }

        container.register { (r) -> UNAuthorizationStatusProviding in
            UNAuthorizationStatusProvider()
        }

        container.register { (r) -> ILogger in
            MBLogger()
        }
        
        container.register { (r) -> NetworkFetcher in
            MBNetworkFetcher(utilitiesFetcher: r.resolveOrDie())
        }
        
        container.register { (r) -> MobileApplicationRepository in
            MBMobileApplicationRepository()
        }
        
        container.register { (r) -> EventRepository in
            MBEventRepository()
        }
        
        container.registerInContainer { [weak self] (r) -> DataBaseLoader in
            if let appGroup = self?.appGroup {
                return try! DataBaseLoader(appGroup: appGroup)
            } else {
                return try! DataBaseLoader()
            }
        }

        container.registerInContainer { (r) -> MBDatabaseRepository in
            let loader: DataBaseLoader = r.resolveOrDie()
            let persistentContainer = try! loader.loadPersistentContainer()
            return try! MBDatabaseRepository(persistentContainer: persistentContainer)
        }
        
        container.registerInContainer { (r) -> GuaranteedDeliveryManager in
            GuaranteedDeliveryManager()
        }
    }

    func dropContainer() {
        container = Odin()
        atOnce = true
    }

}
