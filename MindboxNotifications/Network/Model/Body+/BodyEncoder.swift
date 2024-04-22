//
//  BodyEncoder.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct BodyEncoder<T: Encodable> {
    
    let body: String
    
    init(encodable: T) {
        if let encodedBody = try? JSONEncoder().encode(encodable) {
            body = String(data: encodedBody, encoding: .utf8) ?? ""
        } else {
            body = ""
            Logger.common(message: "BodyEncoder: Failed to encode JSON. encodable: \(encodable)", level: .error, category: .notification)
        }
    }
    
}
