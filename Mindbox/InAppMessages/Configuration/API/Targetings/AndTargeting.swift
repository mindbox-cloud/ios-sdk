//
//  AndTargeting.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//

import Foundation

struct AndTargeting: ITargeting, Decodable {
    let nodes: [Targeting]
}
