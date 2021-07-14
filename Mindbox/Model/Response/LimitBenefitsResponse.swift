//
//  LimitBenefitsResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 01.07.2021.
//

import Foundation

open class LimitBenefitsResponse: Decodable {
    public let period: PeriodTypeResponse?
    public let amount: AmountResponse?
    public let used: Double?
}
