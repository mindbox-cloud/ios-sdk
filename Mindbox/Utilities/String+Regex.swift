//
//  String+Regex.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

extension String {
    var operationNameIsValid: Bool {
        let range = NSRange(location: 0, length: self.utf16.count)
        let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9\\-\\.]+$")
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }
    
    func parseTimeSpanToMillis() throws -> Int64 {
        let regex = try NSRegularExpression(pattern: #"(-)?(\d+\.)?([01]?\d|2[0-3]):([0-5]?\d):([0-5]?\d)(\.\d{1,7})?"#)
        let matches = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
        
        guard let match = matches.first else {
            throw NSError(domain: "Invalid timeSpan format", code: 0, userInfo: nil)
        }
        
        let signRange = Range(match.range(at: 1), in: self)
        let daysRange = Range(match.range(at: 2), in: self)
        let hoursRange = Range(match.range(at: 3), in: self)
        let minutesRange = Range(match.range(at: 4), in: self)
        let secondsRange = Range(match.range(at: 5), in: self)
        let fractionRange = Range(match.range(at: 6), in: self)
        
        let sign = signRange != nil ? String(self[signRange!]) : ""
        let days = daysRange != nil ? String(self[daysRange!]).dropLast() : "0"
        let hours = hoursRange != nil ? String(self[hoursRange!]) : "0"
        let minutes = minutesRange != nil ? String(self[minutesRange!]) : "0"
        let seconds = secondsRange != nil ? String(self[secondsRange!]) : "0"
        let fraction = fractionRange != nil ? String(self[fractionRange!]) : ".0"
        
        let daysCorrected = days.isEmpty ? "0" : days
        
        let durationSeconds: TimeInterval = (Double(daysCorrected)! * 86400) + // days to seconds
                                     (Double(hours)! * 3600) + // hours to seconds
                                     (Double(minutes)! * 60) + // minutes to seconds
                                     (Double(seconds)! + Double(fraction)!) // seconds and fraction
        
        guard durationSeconds <= Double(Int64.max) / 1000 else {
            throw NSError(domain: "Invalid timeSpan format", code: 1, userInfo: nil)
        }

        let millis = Int64(durationSeconds * 1000)
        return sign == "-" ? millis * -1 : millis
    }
}
