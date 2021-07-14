//
//  PushDelivered.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 19.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct PushDelivered: Codable {
    
    let uniqKey: String
    
    init(uniqKey: String) {
        self.uniqKey = uniqKey
    }

}
