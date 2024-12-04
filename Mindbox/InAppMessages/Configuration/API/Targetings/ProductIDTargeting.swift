//
//  ProductIDTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 29.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ProductIDTargeting: ITargeting, Decodable {
    let kind: ProductKind
    let value: String

    enum ProductKind: String, Codable {
        case substring
        case notSubstring
        case startsWith
        case endsWith
    }

    var name: String {
        return value.uppercased()
    }
}
