//
//  MotionServiceShakeToEditTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/25/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

@Suite("MotionService — applicationSupportsShakeToEdit restoration", .tags(.webView))
@MainActor
struct MotionServiceShakeToEditTests {

    @Test("applicationSupportsShakeToEdit is restored after MotionService deallocation")
    func shakeToEditRestoredOnDeinit() async {
        let original = UIApplication.shared.applicationSupportsShakeToEdit

        var service: MotionService? = MotionService()
        service?.startMonitoring(gestures: [.shake])

        // disableShakeToEdit uses DispatchQueue.main.async — let it execute
        await Task.yield()

        #expect(UIApplication.shared.applicationSupportsShakeToEdit == false)

        // Release triggers deinit → DispatchQueue.main.async (without weak self) restores the flag
        service = nil

        await Task.yield()

        #expect(UIApplication.shared.applicationSupportsShakeToEdit == original)
    }

    @Test("applicationSupportsShakeToEdit is restored after stopMonitoring")
    func shakeToEditRestoredOnStop() async {
        let original = UIApplication.shared.applicationSupportsShakeToEdit

        let service = MotionService()
        service.startMonitoring(gestures: [.shake])

        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == false)

        service.stopMonitoring()

        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == original)
    }

    @Test("applicationSupportsShakeToEdit is restored when startMonitoring replaces previous session")
    func shakeToEditRestoredOnRestart() async {
        let original = UIApplication.shared.applicationSupportsShakeToEdit

        let service = MotionService()
        service.startMonitoring(gestures: [.shake])

        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == false)

        // Restart with flip only — shake no longer active, flag should restore
        service.startMonitoring(gestures: [.flip])

        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == original)
    }
}
