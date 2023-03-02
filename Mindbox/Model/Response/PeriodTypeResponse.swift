//
//  PeriodResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 01.07.2021.
//

import Foundation
import MindboxLogger

public enum PeriodTypeResponse: String, UnknownCodable {
    case fixedDays = "FixedDays"
    case fixedMonths = "FixedMonths"
    case fixedWeeks = "FixedWeeks"
    case unknown
}
