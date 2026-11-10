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
    func containerScopeReturnsTheSameInstance() throws {
        let container = MBContainer()
        container.register(First.Service.self, scope: .container) { First.Service() }

        let instance = try #require(container.resolve(First.Service.self))
        #expect(container.resolve(First.Service.self) === instance)
    }

    @Test
    func transientScopeReturnsNewInstances() {
        let container = MBContainer()
        container.register(First.Service.self, scope: .transient) { First.Service() }

        #expect(container.resolve(First.Service.self) !== container.resolve(First.Service.self))
    }
}

@Suite("MBContainer registration", .tags(.dependencyInjection))
struct MBContainerRegistrationTests {

    private protocol Servicing: AnyObject {}
    private final class Service: Servicing {}

    @Test
    func registeringAgainKeepsAlreadyCreatedInstance() {
        let container = MBContainer()
        let original = Service()
        var replacementCalls = 0
        container.register(Service.self) { original }
        let resolvedBefore = container.resolve(Service.self)

        container.register(Service.self) {
            replacementCalls += 1
            return Service()
        }

        #expect(resolvedBefore === original)
        #expect(container.resolve(Service.self) === original)
        #expect(replacementCalls == 0)
    }

    @Test
    func registeringAgainBeforeResolveUsesTheNewFactory() {
        let container = MBContainer()
        let replacement = Service()
        var originalCalls = 0
        container.register(Service.self) {
            originalCalls += 1
            return Service()
        }

        container.register(Service.self) { replacement }

        #expect(container.resolve(Service.self) === replacement)
        #expect(originalCalls == 0)
    }

    @Test
    func protocolTypeResolvesToRegisteredInstance() {
        let container = MBContainer()
        let service = Service()
        container.register(Servicing.self) { service }

        #expect(container.resolve(Servicing.self) === service)
        #expect(container.resolve(Service.self) == nil)
    }

    @Test
    func transientFactoryRunsOnEveryResolve() {
        let container = MBContainer()
        var factoryCalls = 0
        container.register(Servicing.self, scope: .transient) {
            factoryCalls += 1
            return Service()
        }

        let first = container.resolve(Servicing.self)
        let second = container.resolve(Servicing.self)
        let third = container.resolve(Servicing.self)

        #expect(factoryCalls == 3)
        #expect(first !== second && second !== third && first !== third)
    }

    @Test
    func unregisteredTypeResolvesToNil() {
        let container = MBContainer()

        #expect(container.resolve(Servicing.self) == nil)
    }
}
