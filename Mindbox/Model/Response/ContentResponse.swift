//
//  ContentResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class ContentResponse: Decodable {
    public let type: String?
    public let promotion: PromotionResponse?
    public let message: String?
    public let possibleDiscounts: PossibleDiscountsResponse?
}
