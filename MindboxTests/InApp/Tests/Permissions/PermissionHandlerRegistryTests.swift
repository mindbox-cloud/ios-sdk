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

        #expect(sut.handler(for: .location) == nil)
    }

    @Test("Re-registering same type overwrites previous handler")
    func overwritesPreviousHandler() {
        let sut = makeSUT()
        let first = MockPermissionHandler(permissionType: .location, requiredInfoPlistKeys: ["OldKey"])
        let second = MockPermissionHandler(permissionType: .location, requiredInfoPlistKeys: ["NewKey"])

        sut.register(first)
        sut.register(second)

        let retrieved = sut.handler(for: .location)
        #expect(retrieved?.requiredInfoPlistKeys == ["NewKey"])
    }

    @Test("Multiple types registered resolve independently")
    func multipleTypesResolveIndependently() {
        let sut = makeSUT()
        let push = MockPermissionHandler(permissionType: .pushNotifications)
        let location = MockPermissionHandler(permissionType: .location, requiredInfoPlistKeys: ["NSLocationWhenInUseUsageDescription"])

        sut.register(push)
        sut.register(location)

        let retrievedPush = sut.handler(for: .pushNotifications)
        let retrievedLocation = sut.handler(for: .location)

        #expect(retrievedPush?.permissionType == .pushNotifications)
        #expect(retrievedPush?.requiredInfoPlistKeys.isEmpty == true)

        #expect(retrievedLocation?.permissionType == .location)
        #expect(retrievedLocation?.requiredInfoPlistKeys == ["NSLocationWhenInUseUsageDescription"])
    }
}
