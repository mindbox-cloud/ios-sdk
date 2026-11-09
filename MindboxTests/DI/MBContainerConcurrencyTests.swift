//
//  MBContainerConcurrencyTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 08.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

@Suite("MBContainer thread safety", .tags(.dependencyInjection))
struct MBContainerConcurrencyTests {

    private final class Service {}

    @Test
    func concurrentResolveMintsOneInstance() {
        let container = MBContainer()
        let counterLock = NSLock()
        var factoryCalls = 0

        let factoryDelayThatMakesAMissingLockRace: TimeInterval = 0.02
        container.register(Service.self, scope: .container) {
            Thread.sleep(forTimeInterval: factoryDelayThatMakesAMissingLockRace)
            counterLock.lock()
            factoryCalls += 1
            counterLock.unlock()
            return Service()
        }

        let resultsLock = NSLock()
        var identifiers = Set<ObjectIdentifier>()
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            if let service = container.resolve(Service.self) {
                resultsLock.lock()
                identifiers.insert(ObjectIdentifier(service))
                resultsLock.unlock()
            }
        }

        #expect(factoryCalls == 1)
        #expect(identifiers.count == 1)
    }
}

@Suite("MBContainer keys", .tags(.dependencyInjection))
struct MBContainerKeyTests {

    private enum First { final class Service {} }
    private enum Second { final class Service {} }

    @Test
    func typesWithTheSameNameAreDistinct() {
        let container = MBContainer()
        let first = First.Service()
        let second = Second.Service()
        container.register(First.Service.self) { first }
        container.register(Second.Service.self) { second }

        #expect(container.resolve(First.Service.self) === first)
        #expect(container.resolve(Second.Service.self) === second)
    }

    @Test
    func containerScopeReturnsTheSameInstance() {
        let container = MBContainer()
        container.register(First.Service.self, scope: .container) { First.Service() }

        #expect(container.resolve(First.Service.self) === container.resolve(First.Service.self))
    }

    @Test
    func transientScopeReturnsNewInstances() {
        let container = MBContainer()
        container.register(First.Service.self, scope: .transient) { First.Service() }

        #expect(container.resolve(First.Service.self) !== container.resolve(First.Service.self))
    }
}
