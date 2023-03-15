//
//  PossibleDiscountsResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class PossibleDiscountsResponse: Codable {
    public let discountsCount: Int?
    public let discount: DiscountResponse?
    public let products: [ProductElementReponse]?
}
