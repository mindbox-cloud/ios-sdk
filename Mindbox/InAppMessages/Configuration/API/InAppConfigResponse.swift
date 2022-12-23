//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

struct InAppConfigResponse: Decodable {
    let inapps: [FailableDecodable<InApp>]
}

extension InAppConfigResponse {
    struct InApp: Decodable {
        let id: String
        let sdkVersion: SdkVersion
        let targeting: InAppTargeting
        let form: InAppFormVariants
    }
}

// MARK: - SdkVersion
extension InAppConfigResponse {
    struct SdkVersion: Decodable {
        let min: Int
        let max: Int?
    }
}

// MARK: - InAppTargeting
extension InAppConfigResponse {
    struct InAppTargeting: Decodable {
        let type: TargetingType
        let nodes: [TargetingNode]?
        
        init(type: TargetingType, nodes: [TargetingNode]?) {
            self.type = type
            self.nodes = nodes
        }
        
        enum CodingKeys: String, CodingKey {
            case type = "$type"
            case nodes
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(TargetingType.self, forKey: .type)
            self.nodes = try container.decode([TargetingNode].self, forKey: .nodes)
        }
    }
    
    struct TargetingNode: Decodable {
        let type: TargetingType
        
        enum CodingKeys: String, CodingKey {
            case type = "$type"
        }
    }
    
    enum TargetingType: String, Decodable {
        case and
        case or
        case `true`
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

struct FailableDecodable<T: Decodable>: Decodable {
    init(value: T? = nil) {
        self.value = value
    }

    let value: T?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(T.self)
    }
}
