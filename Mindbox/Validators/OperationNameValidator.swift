//
//  OperationNameValidator.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum OperationNameValidator {
    static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9", "-", ".":
                return true
            default:
                return false
            }
        }
    }
}
