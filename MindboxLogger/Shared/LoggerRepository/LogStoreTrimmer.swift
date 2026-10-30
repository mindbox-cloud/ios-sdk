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
    @discardableResult
    func maybeTrim(precomputedSizeKB: Int?, delete: (Double) throws -> Void) throws -> Bool
    
    func computeTrimFraction(sizeKB: Int, limitKB: Int) -> Double?
    
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
