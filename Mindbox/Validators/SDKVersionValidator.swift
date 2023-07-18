//
//  SDKVersionValidator.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

class SDKVersionValidator: Validator {
    typealias T = SdkVersion?
    
    var sdkVersionNumeric: Int
    
    init(sdkVersionNumeric: Int) {
        self.sdkVersionNumeric = sdkVersionNumeric
    }

    func isValid(item: SdkVersion?) -> Bool {
        guard let sdkVersion = item else { return false }
        
        let minVersionValid = sdkVersion.min.map { $0 <= sdkVersionNumeric } ?? false
        let maxVersionValid = sdkVersion.max.map { $0 >= sdkVersionNumeric } ?? true
        
        return minVersionValid && maxVersionValid
    }
}
