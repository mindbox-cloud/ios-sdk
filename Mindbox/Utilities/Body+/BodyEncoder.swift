//
//  BodyEncoder.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct BodyEncoder<T: Encodable> {
    
    let body: String
    
    init(encodable: T) {
        if let encodedBody = try? JSONEncoder().encode(encodable) {
            body = String(data: encodedBody, encoding: .utf8) ?? ""
        } else {
            body = ""
        }
    }
    
}
