//
//  MBContainer.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

enum ObjectScope {
    case transient
    case container
}

class MBContainer {
    private var factories: [String: (ObjectScope, () -> Any)] = [:]
    private var singletons: [String: Any] = [:]

    func register<T>(_ type: T.Type, scope: ObjectScope = .container, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = (scope, factory)
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        if let (scope, factory) = factories[key] {
            switch scope {
            case .container:
                if let instance = singletons[key] as? T {
                    return instance
                }
                let instance = factory()
                singletons[key] = instance
                return instance as? T
            case .transient:
                return factory() as? T
            }
        }
        return nil
    }

    func resolveOrFail<T>(_ serviceType: T.Type) -> T {
        guard let service = self.resolve(serviceType) else {
            fatalError("Service \(serviceType) not found")
        }
        return service
    }
}
