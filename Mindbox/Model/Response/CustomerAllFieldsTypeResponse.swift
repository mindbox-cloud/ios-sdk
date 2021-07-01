//
//  CustomerAllFieldsTypeResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum CustomerAllFieldsTypeResponse: String, Decodable {
    case success = "Success"
    case validationError = "ValidationError"
    case protocolError = "ProtocolError"
    case internalServerError = "InternalServerError"
}
