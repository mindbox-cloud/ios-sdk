//
//  PossibleDiscountsResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class PossibleDiscountsResponse: Decodable {
    public let discountsCount: Int?
    public let discount: DiscountResponse?
    public let products: [ProductElementReponse]?
}
