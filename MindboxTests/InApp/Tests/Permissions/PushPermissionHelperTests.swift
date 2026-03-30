//
//  PushPermissionHelperTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 19.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("PushPermissionHelper", .tags(.webView))
struct PushPermissionHelperTests {

    private func makeRegistry(stubbedResult: PermissionRequestResult) -> (PermissionHandlerRegistry, MockPermissionHandler) {
        let registry = PermissionHandlerRegistry()
        let handler = MockPermissionHandler(permissionType: .pushNotifications)
        handler.stubbedResult = stubbedResult
        registry.register(handler)
        return (registry, handler)
    }

    @Test("requestPermission calls handler and returns granted result")
    func requestPermissionGranted() async {
        let (registry, handler) = makeRegistry(stubbedResult: .granted(dialogShown: true))

        await confirmation { confirm in
            PushPermissionHelper.requestPermission(registry: registry) { result in
                #expect(result == .granted(dialogShown: true))
                confirm()
            }
        }

        #expect(handler.requestCallCount == 1)
    }

    @Test("requestPermission calls handler and returns denied with dialogShown false")
    func requestPermissionDeniedNoDialog() async {
        let (registry, handler) = makeRegistry(stubbedResult: .denied(dialogShown: false))

        await confirmation { confirm in
            PushPermissionHelper.requestPermission(registry: registry) { result in
                #expect(result == .denied(dialogShown: false))
                confirm()
            }
        }

        #expect(handler.requestCallCount == 1)
    }

    @Test("requestPermission calls handler and returns denied with dialogShown true")
    func requestPermissionDeniedWithDialog() async {
        let (registry, handler) = makeRegistry(stubbedResult: .denied(dialogShown: true))

        await confirmation { confirm in
            PushPermissionHelper.requestPermission(registry: registry) { result in
                #expect(result == .denied(dialogShown: true))
                confirm()
            }
        }

        #expect(handler.requestCallCount == 1)
    }

    @Test("requestPermission with no handler does not call completion")
    func requestPermissionNoHandler() async throws {
        let registry = PermissionHandlerRegistry()
        var completionCalled = false

        PushPermissionHelper.requestPermission(registry: registry) { _ in
            completionCalled = true
        }

        #expect(completionCalled == false)
    }
}
