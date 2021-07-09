//
//  PeriodResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 01.07.2021.
//

import Foundation

public enum PeriodTypeResponse: String, UnknownDecodable {
    case fixedDays = "FixedDays"
    case fixedMonths = "FixedMonths"
    case fixedWeeks = "FixedWeeks"
    case unknown
}
