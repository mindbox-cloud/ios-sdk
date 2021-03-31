//
//  UDIDValidator.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct UDIDValidator {
    
    let udid: String
    
    func evaluate() -> Bool {
        return !udid
            .replacingOccurrences(of: "0", with: "")
            .replacingOccurrences(of: "-", with: "")
            .isEmpty
    }

}
