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
        Logger.common(message: "BodyDecoder initialization", level: .info, category: .notification)
        if let data = decodable.data(using: .utf8) {
            if let body = try? JSONDecoder().decode(T.self, from: data) {
                Logger.common(message: "Body decoding successful", level: .info, category: .notification)
                self.body = body
            } else {
                Logger.common(message: "JSON decoding returned nil, Data: \(data)", level: .fault, category: .notification)
                return nil
            }
        } else {
            Logger.common(message: "String decoding returned nil. Data: \(decodable)", level: .fault, category: .notification)
            return nil
        }
    }
    
}
