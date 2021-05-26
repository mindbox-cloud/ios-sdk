//
//  SetPromocode.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class SetPromocode: Codable {
    public var promoCode: PromoCode?

    public init(promoCode: PromoCode?) {
        self.promoCode = promoCode
    }
}
