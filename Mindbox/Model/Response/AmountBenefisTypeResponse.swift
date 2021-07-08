//
//  AmountBenefisTypeResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 01.07.2021.
//

import Foundation

public enum AmountBenefitsTypeResponse: String, Decodable {
    case price = "Price"
    case percent = "Percent"
    case absolute = "Absolute"
}
