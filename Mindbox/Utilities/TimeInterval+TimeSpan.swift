//
//  TimeInterval+TimeSpan.swift
//  Mindbox
//
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

extension TimeInterval {
    func toTimeSpan() -> String {
        let total = abs(self)
        let days = Int(total / 86400)
        let hours = Int(total.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(total.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(total.truncatingRemainder(dividingBy: 60))
        let fraction = total - Double(Int(total))
        let fractionDigits = String(format: "%.7f", fraction).dropFirst(2)

        let prefix = self < 0 ? "-" : ""
        if days > 0 {
            return String(format: "%@%d.%02d:%02d:%02d.%@", prefix, days, hours, minutes, seconds, String(fractionDigits))
        }
        return String(format: "%@%d:%02d:%02d.%@", prefix, hours, minutes, seconds, String(fractionDigits))
    }
}
