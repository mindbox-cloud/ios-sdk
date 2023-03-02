//
//  AmountBenefisTypeResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 01.07.2021.
//

import Foundation
import MindboxLogger

public enum AmountBenefitsTypeResponse: String, UnknownCodable {
    case price = "Price"
    case percent = "Percent"
    case absolute = "Absolute"
    case unknown
}
