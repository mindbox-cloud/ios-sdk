//
//  MBInject.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

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

    // @Locked: read by DI from every queue the SDK runs on; tests' setUp swaps it while a previous
    // test's config queue may still be reading (TSan-confirmed race).
    @Locked static var container: MBContainer = MBInject.buildDefaulContainer()

    @Locked static var mode: InjectionMode = .standard {
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
            .registerCore()
            .registerUtilitiesServices()
            .registerABTestUtilities()
            .registerReplaceableUtilities()
            .registerInappTools()
            .registerInappPresentation()
            .registerEmbeddedBlocks()
    }

    public static var buildTestContainer: () -> MBContainer = {
        let container = MBContainer()
        return container
    }
}

var DI: ModuleInjecting {
    return MBInject.container
}
