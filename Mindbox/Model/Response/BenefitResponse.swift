//
//  BenefitResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class BenefitResponse: Decodable {
    public let amount: AmountBenefitsResponse?
    public let limit: LimitBenefitsResponse?
}
