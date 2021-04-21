//
//  String+Regex.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

extension String {
    var operationNameIsValid: Bool {
        let range = NSRange(location: 0, length: self.utf16.count)
        let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9\\-\\.]+$")
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }
}
