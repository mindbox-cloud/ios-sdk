//
//  OnceFrequency.swift
//  Mindbox
//
//  Created by vailence on 10.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

struct OnceFrequency: iFormVariant, Decodable, Equatable {
    let kind: OnceFrequencyKind
    
    enum OnceFrequencyKind: String, Decodable {
        case lifetime
        case session
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let decodedString = try container.decode(String.self).lowercased()
            guard let value = OnceFrequencyKind(rawValue: decodedString) else {
                throw CustomDecodingError.unknownType("BBBKBKB")
            }
            
            self = value
        }
    }
}
