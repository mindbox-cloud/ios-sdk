//
//  DIManager.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Регистрирует DI-объекты
final class DIManager: NSObject {
    static let shared: DIManager = DIManager()

    private(set) var container: Odin = Odin()

    override private init() {
        super.init()
    }

    func registerServices() {
        defer {
            print("❇️Dependency container registration is complete.")
        }
//        #if DEBUG
//        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
//                // Code only executes when tests are running
//            }
//        #endif
        container.register { (r) -> APIService in
            NetworkManagerProvider(configurationStorage: r.resolveOrDie())
        }

        container.register { (r) -> IMindBoxAPIService in
            MindBoxAPIServicesProvider(serviceManager: r.resolveOrDie())
        }

        container.register { (r) -> IPersistenceStorage in
            MBPersistenceStorage(defaults: UserDefaults.standard )
        }

        container.register { (r) -> ILoger in
            MBLoger()
        }

        container.register { (r) -> IConfigurationStorage in
            MBConfigurationStorage()
        }
    }

}
