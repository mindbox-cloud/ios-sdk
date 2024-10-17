//
//  CategoryIDTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 16.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct CategoryIDTargeting: ITargeting, Decodable {
    let kind: CategoryKind
    let value: String

    enum CategoryKind: String, Codable {
        case substring
        case notSubstring
        case startsWith
        case endsWith
    }

    var name: String {
        return value.uppercased()
    }
}
