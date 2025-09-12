//
//  ABTestDeviceMixer.swift
//  Mindbox
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import CommonCrypto
import MindboxLogger
import Foundation
import MindboxCommon

class ABTestDeviceMixer {
    
    private let abMixer = CustomerAbMixerImpl()

    func modulusGuidHash(identifier: UUID, salt: String) throws -> Int {
        let result: Int32 = abMixer.stringModulusHash(identifier: identifier.uuidString, salt: salt)
        return Int(result)
    }
}
