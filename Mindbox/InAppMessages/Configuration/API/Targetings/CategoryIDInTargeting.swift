//
//  CategoryIDInTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 21.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct CategoryIDInTargeting: ITargeting, Decodable {
    let kind: CategoryKind
    let values: [CategoryIDInValue]
    
    enum CategoryKind: String, Codable {
        case any
        case none
    }
    
    struct CategoryIDInValue: Codable {
        let id: String
        let name: String
        
        enum CodingKeys: String, CodingKey {
            case id = "externalId"
            case name = "externalSystemName"
        }
    }
}
