//
//  ProcessingStatusResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum ProcessingStatusResponse: String, UnknownDecodable {
    case success = "Success"
    case processed = "Processed"
    case notProcessed = "NotProcessed"
    case found = "Found"
    case created = "Created"
    case changed = "Changed"
    case updated = "Updated"
    case calculated = "Calculated"
    case alreadyExists = "AlreadyExists"
    case ambiguous = "Ambiguous"
    case notChanged = "NotChanged"
    case notFound = "NotFound"
    case deleted = "Deleted"
    case requiredEntityMissingFromResponse = "RequiredEntityMissingFromResponse"
    case protocolError = "ProtocolError"
    case validationError = "ValidationError"
    case mindboxServerError = "MindboxServerError"
    case priceHasBeenChanged = "PriceHasBeenChanged"
    case personalDiscountsCalculationIsUnavailable = "PersonalDiscountsCalculationIsUnavailable"
    case discountsCalculationIsUnavailable = "DiscountsCalculationIsUnavailable"
    case unknown
}
