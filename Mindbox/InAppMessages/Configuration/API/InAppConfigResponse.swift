//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

struct InAppConfigResponse: Decodable {
  let inapps: [InApp]
}

extension InAppConfigResponse {
    struct InApp: Decodable {
        let id: String
        let sdkVersion: SdkVersion
        let targeting: Targeting
        let form: InAppFormVariants
    }
    
    struct SdkVersion: Decodable {
        let min: Int
        let max: Int?
    }
}

// MARK: - InAppFormVariants
extension InAppConfigResponse {
    struct InAppFormVariants: Decodable {
        let variants: [InAppForm]
    }
    
    struct InAppForm: Decodable {
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
