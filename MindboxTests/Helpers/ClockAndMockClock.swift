//
//  ClockAndMockClock.swift
//  MindboxTests
//
//  Created by Sergei Semko on 6/23/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

protocol Clock {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

struct MockClock: Clock {
    var now: Date
}
