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

    /// A `.container`-scoped singleton must be minted exactly once even under concurrent
    /// resolves — the recursive lock serializes the check-create-store. Without the lock,
    /// racing resolves each see an empty cache and run the factory more than once.
    @Test
    func concurrentResolveMintsOneInstance() {
        let container = MBContainer()
        let counterLock = NSLock()
        var factoryCalls = 0

        container.register(Service.self, scope: .container) {
            // Widen the check-create-store window so a missing lock reliably races.
            Thread.sleep(forTimeInterval: 0.02)
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
