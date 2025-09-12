//
//  LogStoreTrimmer.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

protocol Clock {
    var now: Date { get }
}

struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

protocol LogStoreTrimming {
    /// Attempts to perform a trim operation if the policy allows it.
    ///
    /// - Parameters:
    ///   - precomputedSizeKB: Optional precomputed database size in kilobytes.
    ///     If provided, the trimmer will **not** call the measurer.
    ///   - delete: A callback that must perform deletion given the computed fraction
    ///     (e.g. delete the oldest `fraction * N` items). May throw.
    /// - Returns: `true` if a trim was performed; `false` if skipped (below limit or under cooldown).
    /// - Throws: Rethrows any error thrown by `delete`.
    @discardableResult
    func maybeTrim(precomputedSizeKB: Int?, delete: (Double) throws -> Void) throws -> Bool
    
    /// Computes the fraction of items to delete in order to reach the configured
    /// low-water mark.
    ///
    /// The result is clamped to `[minDeleteFraction, maxDeleteFraction]`.
    /// Returns `nil` if the current size does not exceed the limit.
    func computeTrimFraction(sizeKB: Int, limitKB: Int) -> Double?
    
    /// Resets cooldown so that the next `maybeTrim` call may run immediately.
    func resetCooldown()
}

final class LogStoreTrimmer: LogStoreTrimming {
    private let config: LoggerDBConfig
    private let sizeMeasurer: DatabaseSizeMeasuring
    private let clock: Clock

    private var cooldownUntil: Date?

    init(config: LoggerDBConfig,
         sizeMeasurer: DatabaseSizeMeasuring,
         clock: Clock) {
        self.config = config
        self.sizeMeasurer = sizeMeasurer
        self.clock = clock
    }

    convenience init(config: LoggerDBConfig,
                     sizeMeasurer: DatabaseSizeMeasuring) {
        self.init(config: config, sizeMeasurer: sizeMeasurer, clock: SystemClock())
    }

    func resetCooldown() { cooldownUntil = nil }

    func computeTrimFraction(sizeKB: Int, limitKB: Int) -> Double? {
        guard sizeKB > limitKB else { return nil }
        let targetKB = Int(Double(limitKB) * config.lowWaterRatio)
        let raw = Double(sizeKB - targetKB) / Double(max(sizeKB, 1))
        let fraction = min(config.maxDeleteFraction, max(config.minDeleteFraction, raw))
        return fraction
    }

    @discardableResult
    func maybeTrim(precomputedSizeKB: Int? = nil,
                   delete: (Double) throws -> Void) rethrows -> Bool {
        if let t = cooldownUntil, t > clock.now { return false }
        let sizeKB = precomputedSizeKB ?? sizeMeasurer.sizeKB()
        guard let fraction = computeTrimFraction(sizeKB: sizeKB, limitKB: config.dbSizeLimitKB) else { return false }
        try delete(fraction)
        cooldownUntil = clock.now.addingTimeInterval(config.trimCooldownSec)
        return true
    }
}

#if DEBUG
final class ManualClock: Clock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}
#endif
