//
//  PermissionHandlerRegistryTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 16.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("PermissionHandlerRegistry", .tags(.webView))
struct PermissionHandlerRegistryTests {

    private func makeSUT() -> PermissionHandlerRegistry {
        PermissionHandlerRegistry()
    }

    @Test("Register handler and retrieve by type")
    func registerAndRetrieve() {
        let sut = makeSUT()
        let handler = MockPermissionHandler(permissionType: .pushNotifications)

        sut.register(handler)

        let retrieved = sut.handler(for: .pushNotifications)
        #expect(retrieved != nil)
        #expect(retrieved?.permissionType == .pushNotifications)
    }

    @Test("Returns nil for unregistered permission type")
    func unregisteredTypeReturnsNil() {
        let sut = makeSUT()

        #expect(sut.handler(for: .pushNotifications) == nil)
    }

    @Test("Re-registering same type overwrites previous handler")
    func overwritesPreviousHandler() {
        let sut = makeSUT()
        let first = MockPermissionHandler(permissionType: .pushNotifications, requiredInfoPlistKeys: ["OldKey"])
        let second = MockPermissionHandler(permissionType: .pushNotifications, requiredInfoPlistKeys: ["NewKey"])

        sut.register(first)
        sut.register(second)

        let retrieved = sut.handler(for: .pushNotifications)
        #expect(retrieved?.requiredInfoPlistKeys == ["NewKey"])
    }
}
