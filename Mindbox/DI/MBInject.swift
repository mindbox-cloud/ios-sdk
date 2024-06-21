//
//  MBInject.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol ModuleInjecting {
    func inject<Dependency>(_ serviceType: Dependency.Type) -> Dependency?
    func injectOrFail<Dependency>(_ serviceType: Dependency.Type) -> Dependency
}

extension MBContainer: ModuleInjecting {
    func inject<Dependency>(_ serviceType: Dependency.Type) -> Dependency? {
        return self.resolve(serviceType)
    }
    
    func injectOrFail<Dependency>(_ serviceType: Dependency.Type) -> Dependency {
        return self.resolveOrFail(serviceType)
    }
}

enum MBInject {
    enum InjectionMode {
        case standard
        case test
    }
    
    static var container: MBContainer = MBInject.buildDefaulContainer()
    
    static var mode: InjectionMode = .standard {
        didSet {
            switch mode {
                case .standard:
                    container = MBInject.buildDefaulContainer()
                case .test:
                    container = MBInject.buildTestContainer()
            }
        }
    }
    
    fileprivate static func buildDefaulContainer() -> MBContainer {
        let container = MBContainer()
        return container
            .registerUtilitiesServices()
            .registerReplaceableUtilities()
    }
    
    public static var buildTestContainer: () -> MBContainer = {
        let container = MBContainer()
        return container
    }
}

var container: ModuleInjecting {
    return MBInject.container
}
