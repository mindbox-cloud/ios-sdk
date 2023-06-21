//
//  ABTestModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ABTest: Decodable, Equatable {
    let id: String
    let sdkVersion: SdkVersion?
    let salt: String?
    let variants: [ABTestVariant]?
    
    struct ABTestVariant: Decodable, Equatable {
        let id: String
        let modulus: Modulus?
        let objects: [ABTestObject]?
        
        struct Modulus: Decodable, Equatable {
            let lower: Int
            let upper: Int?
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
    }
}
