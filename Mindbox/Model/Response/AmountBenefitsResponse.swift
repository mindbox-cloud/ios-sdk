//
//  AmountBenefitsResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 01.07.2021.
//

import Foundation

open class AmountBenefitsResponse: Codable {
    public let type: AmountBenefitsTypeResponse?
    public let value: Double?
}
