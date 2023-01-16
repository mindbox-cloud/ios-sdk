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
        let targeting: TargetingNode
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

protocol DefaultNode {
    var type: InAppConfigResponse.TargetingType { get }
    var nodes: [InAppConfigResponse.TargetingNode]? { get }
}

// MARK: - InAppTargeting
extension InAppConfigResponse {
    struct TargetingNode: DefaultNode, Decodable {
        let type: TargetingType
        let kind: TargetingKind?
        let segmentationExternalId: String?
        let segmentExternalId: String?
        let nodes: [TargetingNode]?
        let ids: [Int]?
        
        enum CodingKeys: String, CodingKey {
            case type = "$type"
            case kind
            case segmentationExternalId
            case segmentExternalId
            case nodes
            case ids
        }
    }
    
    enum TargetingType: String, Decodable {
        case and
        case or
        case `true`
        case segment
        case country
        case region
        case city
    }
    
    enum TargetingKind: String, Decodable {
        case positive
        case negative
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
