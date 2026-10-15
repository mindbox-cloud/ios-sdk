//
//  ConfigVersion.swift
//  Mindbox
//
//  Created by Sergei Semko on 15.10.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

struct ConfigVersion: Comparable, Hashable, CustomStringConvertible {

    let number: Int

    var next: ConfigVersion { ConfigVersion(number: number + 1) }

    var description: String { "\(number)" }

    static func < (lhs: ConfigVersion, rhs: ConfigVersion) -> Bool {
        lhs.number < rhs.number
    }
}
