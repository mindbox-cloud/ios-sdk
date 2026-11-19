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
    private final class Registration<T> {
        let scope: ObjectScope
        let factory: () -> T

        init(scope: ObjectScope, factory: @escaping () -> T) {
            self.scope = scope
            self.factory = factory
        }
    }

    private final class Singleton<T> {
        let instance: T

        init(_ instance: T) {
            self.instance = instance
        }
    }

    private var registrations: [ObjectIdentifier: AnyObject] = [:]
    private var singletons: [ObjectIdentifier: AnyObject] = [:]
    private let lock = NSRecursiveLock()

    func register<T>(_ type: T.Type, scope: ObjectScope = .container, factory: @escaping () -> T) {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        registrations[key] = Registration(scope: scope, factory: factory)
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)

        lock.lock()
        defer { lock.unlock() }
        guard let registration = registrations[key] as? Registration<T> else {
            return nil
        }
        switch registration.scope {
        case .container:
            if let singleton = singletons[key] as? Singleton<T> {
                return singleton.instance
            }
            let instance = registration.factory()
            singletons[key] = Singleton(instance)
            return instance
        case .transient:
            return registration.factory()
        }
    }

    func resolveOrFail<T>(_ serviceType: T.Type) -> T {
        guard let service = self.resolve(serviceType) else {
            fatalError("Service \(serviceType) not found")
        }
        return service
    }
}
