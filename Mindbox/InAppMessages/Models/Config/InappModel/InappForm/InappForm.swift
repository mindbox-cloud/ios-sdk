//
//  InappForm.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InAppForm: Decodable, Equatable {
    let variants: FailableDecodableArray<MindboxFormVariant>
    
    enum CodingKeys: String, CodingKey {
        case variants
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let variants = try container.decode(FailableDecodableArray<MindboxFormVariant>.self, forKey: .variants)
        
        if variants.elements.isEmpty {
            throw CustomDecodingError.decodingError("Variants array cannot be empty.")
        }
        
        self.variants = variants
    }
}
