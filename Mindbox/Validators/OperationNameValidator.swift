//
//  OperationNameValidator.swift
//  Mindbox
//
//  Created by Sergei Semko on 08.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Validates Mindbox operation system names: non-empty, only ASCII letters, digits,
/// `-` and `.`. Regex-free scalar scan - no allocations, no per-call regex compile.
///
/// Intentionally stricter than the legacy `^[A-Za-z0-9\-\.]+$` regex for names with
/// a TRAILING line terminator ("op\n" etc.): ICU `$` matched before a final line
/// terminator, so those were accepted; this scan rejects them. Pinned by
/// `OperationNameValidatorTests`.
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
