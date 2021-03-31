//
//  BodyDecoder.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 11.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct BodyDecoder<T: Decodable> {
    
    let body: T
    
    init?(decodable: String) {
        if let data = decodable.data(using: .utf8) {
            if let body = try? JSONDecoder().decode(T.self, from: data) {
                self.body = body
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
}
