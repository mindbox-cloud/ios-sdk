//
//  MotionServiceResolvePositionTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/25/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import CoreMotion
@testable import Mindbox

@Suite("MotionService.resolvePosition — hysteresis-based flip detection", .tags(.webView))
struct MotionServiceResolvePositionTests {

    // MARK: - Helpers

    private let sut = MotionService()

    private func gravity(x: Double = 0, y: Double = 0, z: Double = 0) -> CMAcceleration {
        CMAcceleration(x: x, y: y, z: z)
    }

    // MARK: - Initial position detection (enterThreshold = 0.8)

    @Test("Detects faceUp when gravity.z < -0.8")
    func faceUp() {
        let result = sut.resolvePosition(gravity: gravity(z: -0.95), current: nil)
        #expect(result == .faceUp)
    }

    @Test("Detects faceDown when gravity.z > 0.8")
    func faceDown() {
        let result = sut.resolvePosition(gravity: gravity(z: 0.95), current: nil)
        #expect(result == .faceDown)
    }

    @Test("Detects portrait when gravity.y < -0.8")
    func portrait() {
        let result = sut.resolvePosition(gravity: gravity(y: -0.95), current: nil)
        #expect(result == .portrait)
    }

    @Test("Detects portraitUpsideDown when gravity.y > 0.8")
    func portraitUpsideDown() {
        let result = sut.resolvePosition(gravity: gravity(y: 0.95), current: nil)
        #expect(result == .portraitUpsideDown)
    }

    @Test("Detects landscapeLeft when gravity.x < -0.8")
    func landscapeLeft() {
        let result = sut.resolvePosition(gravity: gravity(x: -0.95), current: nil)
        #expect(result == .landscapeLeft)
    }

    @Test("Detects landscapeRight when gravity.x > 0.8")
    func landscapeRight() {
        let result = sut.resolvePosition(gravity: gravity(x: 0.95), current: nil)
        #expect(result == .landscapeRight)
    }

    // MARK: - Dead zone (no position when all axes below enterThreshold)

    @Test("Returns nil when no axis exceeds enterThreshold (dead zone)")
    func deadZone() {
        let result = sut.resolvePosition(gravity: gravity(x: 0.5, y: -0.5, z: 0.3), current: nil)
        #expect(result == nil)
    }

    @Test("Returns nil at exactly enterThreshold (0.8 is not > 0.8)")
    func exactlyAtEnterThreshold() {
        let result = sut.resolvePosition(gravity: gravity(z: -0.8), current: nil)
        #expect(result == nil)
    }

    // MARK: - Hysteresis: position holds above exitThreshold (0.6)

    @Test("Current position holds while gravity stays above exitThreshold")
    func positionHoldsAboveExitThreshold() {
        // Gravity weakens to 0.65 — still above exitThreshold (0.6)
        let result = sut.resolvePosition(gravity: gravity(z: -0.65), current: .faceUp)
        #expect(result == .faceUp)
    }

    @Test("Current position lost when gravity drops below exitThreshold")
    func positionLostBelowExitThreshold() {
        // Gravity drops to 0.5 — below exitThreshold (0.6)
        // No other axis above enterThreshold — returns nil
        let result = sut.resolvePosition(gravity: gravity(y: -0.5, z: -0.5), current: .faceUp)
        #expect(result == nil)
    }

    // MARK: - Transition between positions

    @Test("Transitions from faceUp to faceDown")
    func transitionFaceUpToFaceDown() {
        // Gravity flips: z goes from negative to positive > 0.8
        let result = sut.resolvePosition(gravity: gravity(z: 0.9), current: .faceUp)
        #expect(result == .faceDown)
    }

    @Test("Transitions from portrait to portraitUpsideDown")
    func transitionPortraitToUpsideDown() {
        let result = sut.resolvePosition(gravity: gravity(y: 0.9), current: .portrait)
        #expect(result == .portraitUpsideDown)
    }

    @Test("Transitions from portrait through intermediate to faceDown")
    func transitionWithIntermediate() {
        // Phone tilts — exits portrait, enters faceUp
        let step1 = sut.resolvePosition(gravity: gravity(z: -0.9), current: .portrait)
        #expect(step1 == .faceUp)

        // Continues to faceDown
        let step2 = sut.resolvePosition(gravity: gravity(z: 0.9), current: .faceUp)
        #expect(step2 == .faceDown)
    }

    // MARK: - Dominant axis selection

    @Test("Selects dominant axis when multiple exceed enterThreshold")
    func dominantAxisSelection() {
        // Both z and y exceed 0.8, but z is stronger
        let result = sut.resolvePosition(gravity: gravity(y: -0.85, z: -0.9), current: nil)
        #expect(result == .faceUp)
    }

    @Test("Selects y-axis when it dominates over z")
    func yAxisDominates() {
        let result = sut.resolvePosition(gravity: gravity(y: -0.95, z: -0.85), current: nil)
        #expect(result == .portrait)
    }

    // MARK: - Hysteresis prevents flickering

    @Test("No flickering at boundary — current position wins in dead zone")
    func noFlickeringAtBoundary() {
        // gravity.y = -0.65 (above exit 0.6), gravity.z = -0.7 (below enter 0.8)
        // portrait should hold because it's still above exitThreshold
        let result = sut.resolvePosition(gravity: gravity(y: -0.65, z: -0.7), current: .portrait)
        #expect(result == .portrait)
    }
}
