//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation
import MindboxLogger

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
        inapps = InAppConfigResponse.decodeIfPresent(container, forKey: .inapps, errorDesc: "Cannot decode InApps")
        monitoring = InAppConfigResponse.decodeIfPresent(container, forKey: .monitoring, errorDesc: "Cannot decode Monitoring")
        settings = InAppConfigResponse.decodeIfPresent(container, forKey: .settings, errorDesc: "Cannot decode Settings")
        
        if let decodedAbtests: [ABTest] = InAppConfigResponse.decodeIfPresent(container, forKey: .abtests, errorDesc: "Cannot decode ABTests") {
            if decodedAbtests.contains(where: { $0.variants?.count ?? 0 < 2
                || $0.variants?.contains(where: { $0.objects.isEmpty }) == true }) {
                abtests = nil
            } else {
                abtests = decodedAbtests
            }
        } else {
            abtests = nil
        }
    }
    
    private static func decodeIfPresent<T>(_ container: KeyedDecodingContainer<CodingKeys>,
                                           forKey key: CodingKeys,
                                           errorDesc: String) -> T? where T: Decodable {
        do {
            return try container.decodeIfPresent(T.self, forKey: key)
        } catch {
            Logger.error(.internalError(.init(errorKey: .parsing, reason: errorDesc)))
            return nil
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
    struct InApp: Decodable, Equatable {
        let id: String
        let sdkVersion: SdkVersion
        let targeting: Targeting
        let form: InAppFormVariants
    }
    
    struct SdkVersion: Decodable, Equatable {
        let min: Int?
        let max: Int?
    }
    
    struct Monitoring: Decodable, Equatable {
        let logs: [Logs]
        
        struct Logs: Decodable, Equatable {
            let requestId: String
            let deviceUUID: String
            let from: String
            let to: String
        }
    }
    
    struct Settings: Decodable, Equatable {
        let operations: SettingsOperations?
        
        struct SettingsOperations: Decodable, Equatable {
            
            let viewProduct: Operation?
            let viewCategory: Operation?
            let setCart: Operation?
            
            struct Operation: Decodable, Equatable {
                let systemName: String
            }
        }
    }
    
    struct ABTest: Decodable, Equatable {
        let id: String
        let sdkVersion: SdkVersion
        let salt: String
        let variants: [ABTestVariant]?
        
        struct ABTestVariant: Decodable, Sequence, Equatable {
            let id: String
            let modulus: Modulus
            let objects: [ABTestObject]
            
            struct Modulus: Decodable, Equatable {
                let lower: Int
                let upper: Int
            }
            
            struct ABTestObject: Decodable, Equatable {
                let type: ABTestType
                let kind: ABTestKind
                let inapps: [String]?

                enum CodingKeys: String, CodingKey {
                    case type = "$type"
                    case kind
                    case inapps
                }

                enum ABTestType: String, Decodable {
                    case inapps
                    case unknown
                }

                enum ABTestKind: String, Decodable {
                    case all
                    case concrete
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let typeValue = try container.decodeIfPresent(String.self, forKey: .type),
                       let type = ABTestType(rawValue: typeValue) {
                        self.type = type
                    } else {
                        self.type = .unknown
                    }

                    kind = try container.decode(ABTestKind.self, forKey: .kind)
                    inapps = try container.decodeIfPresent([String].self, forKey: .inapps)
                }
                
                init(type: ABTestType, kind: ABTestKind, inapps: [String]? = nil) {
                     self.type = type
                     self.kind = kind
                     self.inapps = inapps
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
