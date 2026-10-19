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

@Suite("System shake relay", .tags(.webView), .serialized)
@MainActor
struct SystemShakeRelayTests {

    /// Stands in for the application: the test bundle runs with no host, so there is no `UIApplication.shared`.
    private final class ApplicationStandIn: UIResponder {}

    @Test("A shake that reaches the relayed responder is posted once, other motions are not")
    func shakeAtTheRelayedResponderIsPosted() {
        SystemShakeRelay.relayShakes(of: ApplicationStandIn.self)
        var heard = 0
        let token = NotificationCenter.default.addObserver(forName: SystemShakeRelay.didShake, object: nil, queue: nil) { _ in
            heard += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        ApplicationStandIn().motionEnded(.motionShake, with: nil)
        ApplicationStandIn().motionEnded(.none, with: nil)

        #expect(heard == 1)
    }

    @Test("Other responders are left as they were")
    func otherRespondersAreUntouched() {
        SystemShakeRelay.relayShakes(of: ApplicationStandIn.self)
        var heard = 0
        let token = NotificationCenter.default.addObserver(forName: SystemShakeRelay.didShake, object: nil, queue: nil) { _ in
            heard += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        UIView().motionEnded(.motionShake, with: nil)
        UIResponder().motionEnded(.motionShake, with: nil)

        #expect(heard == 0)
    }

    @Test("Installing with no application around does nothing and does not crash")
    func installWithoutAnApplicationIsSafe() {
        SystemShakeRelay.installIfNeeded()
        SystemShakeRelay.installIfNeeded()
    }
}
