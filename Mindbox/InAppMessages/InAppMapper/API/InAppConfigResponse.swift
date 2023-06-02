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
    let abtests: [ABTest]?
    
    enum CodingKeys: String, CodingKey {
        case inapps, monitoring, settings, abtests
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        inapps = try container.decodeIfPresent([InApp].self, forKey: .inapps)
        monitoring = try container.decodeIfPresent(Monitoring.self, forKey: .monitoring)
        settings = try container.decodeIfPresent(Settings.self, forKey: .settings)
        
        // Try decoding abtests, if it fails, assign it to nil or an empty array
        do {
            abtests = try container.decodeIfPresent([ABTest].self, forKey: .abtests)
        } catch {
            abtests = nil
        }
    }
    
    init(inapps: [InAppConfigResponse.InApp]? = nil, monitoring: InAppConfigResponse.Monitoring? = nil, settings: InAppConfigResponse.Settings? = nil, abtests: [InAppConfigResponse.ABTest]? = nil) {
        self.inapps = inapps
        self.monitoring = monitoring
        self.settings = settings
        self.abtests = abtests
    }
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
    
    struct ABTest: Decodable {
        let id: String
        let sdkVersion: SdkVersion
        let salt: String
        let variants: [ABTestVariant]?
        
        struct ABTestVariant: Decodable, Sequence {
            let modulus: Modulus
            let objects: [ABTestObject]
            
            struct Modulus: Decodable {
                let lower: Int
                let upper: Int
            }
            
            struct ABTestObject: Decodable {
                let type: String
                let kind: ABTestKind
                let inapps: [String]?
                
                enum CodingKeys: String, CodingKey {
                    case type = "$type"
                    case kind
                    case inapps
                }
                
                enum ABTestKind: String, Decodable {
                    case all
                    case concrete
                }
            }
            
            func makeIterator() -> IndexingIterator<[ABTestObject]> {
                return objects.makeIterator()
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
