//
//  CustomEvent.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 19.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct CustomEvent: Codable {
    let name: String
    let payload: String
    
    init(name: String, payload: String) {
        self.name = name
        self.payload = payload
    }
}
