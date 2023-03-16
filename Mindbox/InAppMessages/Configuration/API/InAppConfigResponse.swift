//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

struct InAppConfigResponse: Decodable {
    let inapps: [InApp]?
    let monitoring: Monitoring?
    let settings: Settings?
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
    
    struct Monitoring: Decodable {
        let logs: [Logs]
        
        struct Logs: Decodable {
            let requestId: String
            let deviceUUID: String
            let from: String
            let to: String
        }
    }
    
    struct Settings: Decodable {
        let operations: SettingsOperations?
        
        struct SettingsOperations: Decodable {
            
            let viewProduct: Operation?
            let viewCategory: Operation?
            let setCart: Operation?
            
            struct Operation: Decodable {
                let systemName: String
            }
        }
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
