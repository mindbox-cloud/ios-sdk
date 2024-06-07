//
//  MBInjectUtilities.swift
//  Mindbox
//
//  Created by Sergei Semko on 6/3/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension Container {
    func registerUtilitiesServices() -> Self {
        register(UtilitiesFetcher.self) {
            MBUtilitiesFetcher()
        }
        
        register(PersistenceStorage.self) {
            MBPersistenceStorage()
        }
        
        register(ABTestDeviceMixer.self) {
            ABTestDeviceMixer()
        }
        
        register(TimerManager.self) {
            TimerManager()
        }
        
        register(UserVisitManagerProtocol.self) {
            UserVisitManager()
        }
        
        return self
    }
}
