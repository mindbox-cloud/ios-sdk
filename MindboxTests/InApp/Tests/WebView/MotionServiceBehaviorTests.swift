//
//  MotionServiceBehaviorTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/28/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import UIKit
@testable import Mindbox

@Suite("MotionService — monitoring lifecycle behavior", .tags(.webView))
@MainActor
struct MotionServiceBehaviorTests {

    @Test("stopMonitoring without prior startMonitoring is a no-op")
    func stopWithoutStartIsNoOp() async {
        let original = UIApplication.shared.applicationSupportsShakeToEdit

        let service = MotionService()
        service.stopMonitoring()

        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == original)
    }

    @Test("Double stopMonitoring after startMonitoring does not crash or alter state")
    func doubleStopIsNoOp() async {
        let original = UIApplication.shared.applicationSupportsShakeToEdit

        let service = MotionService()
        service.startMonitoring(gestures: [.shake])

        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == false)

        service.stopMonitoring()
        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == original)

        // Second stop — should be a no-op, no side effects
        service.stopMonitoring()
        await Task.yield()
        #expect(UIApplication.shared.applicationSupportsShakeToEdit == original)
    }

    @Test("Repeated startMonitoring replaces previous gesture set")
    func restartReplacesGestures() {
        let service = MotionService()

        let result1 = service.startMonitoring(gestures: [.shake, .flip])
        #expect(result1.started.contains(.shake))

        // Restart with only flip — shake should no longer be active
        let result2 = service.startMonitoring(gestures: [.flip])
        #expect(!result2.started.contains(.shake))

        // Verify shake handler does not fire after restart without shake
        var gestureReceived = false
        service.onGestureDetected = { gesture, _ in
            if gesture == .shake { gestureReceived = true }
        }
        service.handleSystemShake()
        #expect(!gestureReceived)
    }
}
