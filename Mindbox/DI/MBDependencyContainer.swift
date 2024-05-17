//
//  MBDependencyContainer.swift
//  Mindbox
//
//  Created by vailence on 16.05.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

class Container {
    private var services = [String: () -> Any]()
    private var singletons = [String: Any]()
    private let queue = DispatchQueue(label: "com.MBDependencyContainer.queue")

    init() {}

    func register<T>(_ serviceType: T.Type, factory: @escaping () -> T, isSingleton: Bool = false) {
        let key = String(describing: serviceType)
        queue.sync {
            if isSingleton {
                singletons[key] = factory()
            } else {
                services[key] = factory
            }
        }
    }

    func resolve<T>(_ serviceType: T.Type) -> T? {
        let key = String(describing: serviceType)
        return queue.sync {
            if let singleton = singletons[key] as? T {
                return singleton
            }
            guard let factory = services[key] else {
                return nil
            }
            return factory() as? T
        }
    }
}

extension Container {
    func resolveOrFail<T>(_ serviceType: T.Type) -> T {
        guard let service = self.resolve(serviceType) else {
            fatalError("Service \(serviceType) not found")
        }
        return service
    }
}
