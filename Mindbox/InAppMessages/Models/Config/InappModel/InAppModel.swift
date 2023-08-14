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
    let form: InAppForm
    
    enum CodingKeys: String, CodingKey {
        case id
        case sdkVersion
        case targeting
        case form
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sdkVersion = try container.decode(SdkVersion.self, forKey: .sdkVersion)
        targeting = try container.decode(Targeting.self, forKey: .targeting)
        form = try container.decode(InAppForm.self, forKey: .form)
        
        if !InappValidator().isValid(item: self) {
            throw CustomDecodingError.decodingError("The inapp not passed validation. The inapp will be ignored.")
        }
    }
}
