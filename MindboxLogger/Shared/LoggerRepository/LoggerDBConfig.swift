//
//  LoggerDBConfig.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

public struct LoggerDBConfig {
    public let dbSizeLimitKB: Int
    public let lowWaterRatio: Double
    public let minDeleteFraction: Double
    public let maxDeleteFraction: Double
    public let batchSize: Int
    public let writesPerTrimCheck: Int
    public let trimCooldownSec: TimeInterval

    public static let `default` = LoggerDBConfig(
        dbSizeLimitKB: 10_240,
        lowWaterRatio: 0.85,
        minDeleteFraction: 0.05,
        maxDeleteFraction: 0.50,
        batchSize: 15,
        writesPerTrimCheck: 5,
        trimCooldownSec: 10
    )
}
