//
//  ContentResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class ContentResponse: Codable {
    public let type: String?
    public let promotion: PromotionResponse?
    public let message: String?
    public let possibleDiscounts: PossibleDiscountsResponse?
}
