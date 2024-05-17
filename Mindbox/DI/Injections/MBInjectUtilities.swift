//
//  MBInjectUtilities.swift
//  Mindbox
//
//  Created by vailence on 16.05.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension Container {
    func registerUtilitiesServices() -> Self {
        register(ABTestDeviceMixer.self) {
            ABTestDeviceMixer()
        }
        
        register(TimerManager.self, factory: {
            TimerManager()
        }, isSingleton: true)
        
        return self
    }
    
    func registerStubUtilitiesServices() -> Self {
        register(ABTestDeviceMixer.self) {
            StubABTestDeviceMixer()
        }
        return self
    }
}

