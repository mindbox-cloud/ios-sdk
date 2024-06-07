//
//  MBDependancyContainer.swift
//  Mindbox
//
//  Created by Sergei Semko on 6/3/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

class Container {
    private var services: Dictionary<ObjectIdentifier, Any> = [ObjectIdentifier: Any]()
    private let queue = DispatchQueue(label: "com.MBDependencyContainer.queue", attributes: .concurrent)
    
    init() {}
    
    func register<T>(_ serviceType: T.Type, _ factory: @escaping () -> T) {
        let key = ObjectIdentifier(serviceType)
        queue.async(flags: .barrier) {
            self.services[key] = factory()
        }
    }
    
    func resolve<T>(_ serviceType: T.Type) -> T? {
        let key = ObjectIdentifier(serviceType)
        
        return queue.sync {
            guard let service = services[key] as? T else {
                return nil
            }
            return service
        }
    }
    
    func resolveAsync<T>(_ serviceType: T.Type, completion: @escaping (T?) -> Void) {
        let key = ObjectIdentifier(serviceType)
        queue.async {
            let service = self.services[key] as? T
            completion(service)
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
    
    func resolveOrFailAsync<T>(_ serviceType: T.Type) -> T {
        var resultService: T
        self.resolveAsync(serviceType) { service in
            resultService = service!
        }
        return resultService
    }
}
