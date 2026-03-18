//
//  HapticRequestValidatorTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("HapticRequestValidator", .tags(.webView))
struct HapticRequestValidatorTests {

    // MARK: - Helpers

    private func validEvent(
        time: Double = 0,
        duration: Double = 100,
        intensity: Double = 1.0,
        sharpness: Double = 0.0
    ) -> HapticPatternEvent {
        HapticPatternEvent(time: time, duration: duration, intensity: intensity, sharpness: sharpness)
    }

    // MARK: - Selection / Impact / Notification always valid

    @Test("selection is always valid")
    func selectionValid() {
        #expect(HapticRequestValidator.isValid(.selection))
    }

    @Test(
        "impact is always valid for any style",
        arguments: HapticRequest.ImpactStyle.allCases
    )
    func impactValid(style: HapticRequest.ImpactStyle) {
        #expect(HapticRequestValidator.isValid(.impact(style)))
    }

    @Test(
        "notification is always valid for any style",
        arguments: HapticRequest.NotificationStyle.allCases
    )
    func notificationValid(style: HapticRequest.NotificationStyle) {
        #expect(HapticRequestValidator.isValid(.notification(style)))
    }

    // MARK: - Pattern: empty

    @Test("empty pattern is invalid")
    func emptyPattern() {
        #expect(!HapticRequestValidator.isValid(.pattern([])))
    }

    // MARK: - Pattern: event count

    @Test("pattern with more than 128 events is invalid")
    func tooManyEvents() {
        let events = (0..<129).map { validEvent(time: Double($0) * 100) }
        #expect(!HapticRequestValidator.isValid(.pattern(events)))
    }

    @Test("pattern with exactly 128 events is valid")
    func exactlyMaxEvents() {
        let events = (0..<128).map { validEvent(time: Double($0) * 200) }
        #expect(HapticRequestValidator.isValid(.pattern(events)))
    }

    @Test("single valid event is valid")
    func singleValidEvent() {
        #expect(HapticRequestValidator.isValid(.pattern([validEvent()])))
    }

    // MARK: - Pattern: time

    @Test("negative time is invalid")
    func negativeTime() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(time: -1)])))
    }

    @Test("time exceeding 30000 is invalid")
    func timeExceedsMax() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(time: 30_001)])))
    }

    @Test("time at boundaries 0 and 30000 is valid")
    func timeBoundaries() {
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(time: 0)])))
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(time: 30_000, duration: 0)])))
    }

    // MARK: - Pattern: duration

    @Test("negative duration is invalid")
    func negativeDuration() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(duration: -1)])))
    }

    @Test("duration exceeding 5000 is invalid")
    func durationExceedsMax() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(duration: 5_001)])))
    }

    @Test("duration at boundaries 0 and 5000 is valid")
    func durationBoundaries() {
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(duration: 0)])))
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(duration: 5_000)])))
    }

    // MARK: - Pattern: intensity

    @Test("intensity below 0 is invalid")
    func intensityBelowZero() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(intensity: -0.1)])))
    }

    @Test("intensity above 1 is invalid")
    func intensityAboveOne() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(intensity: 1.1)])))
    }

    @Test("intensity at boundaries 0 and 1 is valid")
    func intensityBoundaries() {
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(intensity: 0)])))
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(intensity: 1)])))
    }

    // MARK: - Pattern: sharpness

    @Test("sharpness below 0 is invalid")
    func sharpnessBelowZero() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(sharpness: -0.1)])))
    }

    @Test("sharpness above 1 is invalid")
    func sharpnessAboveOne() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(sharpness: 1.1)])))
    }

    @Test("sharpness at boundaries 0 and 1 is valid")
    func sharpnessBoundaries() {
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(sharpness: 0)])))
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(sharpness: 1)])))
    }

    // MARK: - Pattern: time + duration

    @Test("time + duration exceeding 30000 is invalid")
    func timePlusDurationExceedsMax() {
        #expect(!HapticRequestValidator.isValid(.pattern([validEvent(time: 28_000, duration: 2_001)])))
    }

    @Test("time + duration exactly 30000 is valid")
    func timePlusDurationAtMax() {
        #expect(HapticRequestValidator.isValid(.pattern([validEvent(time: 25_000, duration: 5_000)])))
    }

    // MARK: - Pattern: mixed valid and invalid

    @Test("any invalid event makes entire pattern invalid")
    func oneInvalidEventInvalidatesAll() {
        let events = [
            validEvent(time: 0),
            validEvent(time: 1000, duration: 10_000),
        ]
        #expect(!HapticRequestValidator.isValid(.pattern(events)))
    }
}
