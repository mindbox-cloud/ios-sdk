//
//  OrTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//

import Foundation

struct OrTargeting: ITargeting, Decodable {
    let nodes: [Targeting]
}
