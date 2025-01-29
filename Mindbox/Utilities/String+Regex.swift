//
//  String+Regex.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

// swiftlint:disable force_unwrapping

extension String {
    var operationNameIsValid: Bool {
        let range = NSRange(location: 0, length: self.utf16.count)
        let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9\\-\\.]+$")
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }

    func parseTimeSpanToMillis() throws -> Int64 {
        let regex = try NSRegularExpression(pattern: "^(-)?((\\d+)\\.)?([01]?\\d|2[0-3]):([0-5]?\\d):([0-5]?\\d)(\\.(\\d{1,7}))?$")
        let matches = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))

        guard let match = matches.first else {
            throw NSError(domain: "Invalid timeSpan format", code: 0, userInfo: nil)
        }

        let signRange = Range(match.range(at: 1), in: self)
        let daysRange = Range(match.range(at: 3), in: self)
        let hoursRange = Range(match.range(at: 4), in: self)
        let minutesRange = Range(match.range(at: 5), in: self)
        let secondsRange = Range(match.range(at: 6), in: self)
        let fractionRange = Range(match.range(at: 8), in: self)

        let sign = signRange != nil ? String(self[signRange!]) : ""
        let days = daysRange != nil ? String(self[daysRange!]) : "0"
        let hours = hoursRange != nil ? String(self[hoursRange!]) : "0"
        let minutes = minutesRange != nil ? String(self[minutesRange!]) : "0"
        let seconds = secondsRange != nil ? String(self[secondsRange!]) : "0"
        let fraction = fractionRange != nil ? String(self[fractionRange!]) : "0"

        let daysCorrected = days.isEmpty ? "0" : days
        let fractionCorrected = fraction.isEmpty ? "0" : fraction

        let daysInSeconds = NSDecimalNumber(string: daysCorrected).multiplying(by: 86_400)
        let hoursInSeconds = NSDecimalNumber(string: hours).multiplying(by: 3600)
        let minutesInSeconds = NSDecimalNumber(string: minutes).multiplying(by: 60)
        let secondsInSeconds = NSDecimalNumber(string: seconds)
        let fractionInSeconds = NSDecimalNumber(string: "0.\(fractionCorrected)")

        let totalSeconds = daysInSeconds
            .adding(hoursInSeconds)
            .adding(minutesInSeconds)
            .adding(secondsInSeconds)
            .adding(fractionInSeconds)
        let totalMilliseconds = totalSeconds.multiplying(by: 1000)

        let roundingBehavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 1,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let roundedMilliseconds = totalMilliseconds.rounding(accordingToBehavior: roundingBehavior)

        guard roundedMilliseconds.compare(NSDecimalNumber(value: Int64.max)) != .orderedDescending else {
            throw NSError(domain: "Invalid timeSpan format", code: 1, userInfo: nil)
        }

        let millis = roundedMilliseconds.int64Value

        return sign == "-" ? -millis : millis
    }

    func parseTimeStampToSeconds() throws -> Int64 {
        try parseTimeSpanToMillis() / 1000
    }
}
