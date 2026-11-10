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
    /// Stores a factory with its static type, so `resolve` casts to a concrete
    /// generic class instead of casting `Any` to a (possibly protocol) `T`.
    private final class Registration<T> {
        let scope: ObjectScope
        let factory: () -> T

        init(scope: ObjectScope, factory: @escaping () -> T) {
            self.scope = scope
            self.factory = factory
        }
    }

    /// Keeps a `.container` instance with its static type.
    /// Lives apart from `Registration`, so registering a type again
    /// does not drop an instance that was already created.
    private final class Instance<T> {
        let value: T

        init(_ value: T) {
            self.value = value
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
            if let instance = singletons[key] as? Instance<T> {
                return instance.value
            }
            let value = registration.factory()
            singletons[key] = Instance(value)
            return value
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
