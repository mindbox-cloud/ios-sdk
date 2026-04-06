//
//  HapticRequestValidator.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum HapticRequestValidator {

    private enum Limits {
        static let maxEvents = 128
        static let maxTotalDurationMs: Double = 30_000
        static let maxSingleEventDurationMs: Double = 5_000
    }

    static func isValid(_ request: HapticRequest) -> Bool {
        switch request {
        case .selection, .impact, .notification:
            return true
        case .pattern(let events):
            return isValidPattern(events)
        }
    }

    private static func isValidPattern(_ events: [HapticPatternEvent]) -> Bool {
        guard !events.isEmpty else {
            return logAndFail("pattern is empty")
        }
        guard events.count <= Limits.maxEvents else {
            return logAndFail("too many events: \(events.count)")
        }
        return events.allSatisfy { isValidEvent($0) }
    }

    private static func isValidEvent(_ event: HapticPatternEvent) -> Bool {
        guard event.time >= 0, event.time <= Limits.maxTotalDurationMs else {
            return logAndFail("event time out of range: \(event.time)")
        }
        guard event.duration >= 0, event.duration <= Limits.maxSingleEventDurationMs else {
            return logAndFail("event duration out of range: \(event.duration)")
        }
        guard event.intensity >= 0, event.intensity <= 1 else {
            return logAndFail("event intensity out of range: \(event.intensity)")
        }
        guard event.sharpness >= 0, event.sharpness <= 1 else {
            return logAndFail("event sharpness out of range: \(event.sharpness)")
        }
        guard event.time + event.duration <= Limits.maxTotalDurationMs else {
            return logAndFail("event time + duration exceeds max: \(event.time + event.duration)")
        }
        return true
    }

    private static func logAndFail(_ reason: String) -> Bool {
        Logger.common(
            message: "[WebView] Invalid haptic pattern: \(reason)",
            level: .info,
            category: .webViewInAppMessages
        )
        return false
    }
}
