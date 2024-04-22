//
//  BodyDecoder.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct BodyDecoder<T: Decodable> {
    
    let body: T
    
    init?(decodable: String) {
        if let data = decodable.data(using: .utf8) {
            if let body = try? JSONDecoder().decode(T.self, from: data) {
                self.body = body
            } else {
                Logger.common(message: "BodyDecoder: Failed to decode JSON. data: \(data)", level: .error, category: .notification)
                return nil
            }
        } else {
            Logger.common(message: "BodyDecoder: Failed to decode string. decodable: \(decodable)", level: .error, category: .notification)
            return nil
        }
    }
    
}
