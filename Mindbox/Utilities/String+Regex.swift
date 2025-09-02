//
//  String+Regex.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxCommon

extension String {
    var operationNameIsValid: Bool {
        let range = NSRange(location: 0, length: self.utf16.count)
        let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9\\-\\.]+$")
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }

    func parseTimeSpanToMillis() throws -> Int64 {
        return try TimeSpanParserKt.parseTimeSpanToMillis(self)
    }

    func parseTimeSpanToSeconds() throws -> Int64 {
        try parseTimeSpanToMillis() / 1000
    }
}
