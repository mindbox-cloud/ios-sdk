//
//  Status.swift
//  MindboxLogger
//
//  Created by vailence on 28.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

public enum Status: String, UnknownCodable {
    case success = "Success"
    case validationError = "ValidationError"
    case protocolError = "ProtocolError"
    case internalServerError = "InternalServerError"
    case transactionAlreadyProcessed = "TransactionAlreadyProcessed"
    case unknown
}
