//
//  InAppModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InApp: Decodable, Equatable {
    let id: String
    let sdkVersion: SdkVersion
    let targeting: Targeting
    let form: InAppFormVariants
    
    struct InAppFormVariants: Decodable, Equatable {
        let variants: [InAppForm]
    }
    
    struct InAppForm: Decodable, Equatable {
        let imageUrl: String
        let redirectUrl: String
        let intentPayload: String
        let type: String
        
        enum CodingKeys: String, CodingKey {
            case imageUrl
            case redirectUrl
            case intentPayload
            case type = "$type"
        }
    }
}
