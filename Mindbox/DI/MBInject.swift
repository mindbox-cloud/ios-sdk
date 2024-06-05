//
//  MBInject.swift
//  Mindbox
//
//  Created by Sergei Semko on 6/3/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol ModuleInjector {
    func inject<Dependency>(_ serviceType: Dependency.Type) -> Dependency?
    func inject<Dependency>(_ serviceType: Dependency.Type) -> Dependency
}

extension Container: ModuleInjector {
    func inject<Dependency>(_ serviceType: Dependency.Type) -> Dependency? {
        self.resolve(serviceType)
    }
    
    func inject<Dependency>(_ serviceType: Dependency.Type) -> Dependency {
        self.resolveOrFail(serviceType)
    }
}

enum MBInject {
    enum InjectionMode {
        case standard
        case test((Container) -> Container)
    }
    
    static var mode: InjectionMode = .standard {
        didSet {
            switch mode {
            case .standard:
                depContainer = MBInject.buildDefaultContainer()
                
            case .test(let registerTestDependenciesClosure):
                depContainer = MBInject.buildTestContainer(registerTestDependenciesClosure)
            }
        }
    }
    
    static var depContainer: Container = MBInject.buildDefaultContainer()
    
    fileprivate static func buildDefaultContainer() -> Container {
        let container = Container()
        return container
            .registerUtilitiesServices()
    }
    
    fileprivate static func buildTestContainer(
        _ registerDependencies: (Container) -> Container
    ) -> Container {
        let container = Self.buildDefaultContainer()
        return registerDependencies(container)
    }
}

var container: ModuleInjector {
    return MBInject.depContainer
}
