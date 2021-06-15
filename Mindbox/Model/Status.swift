//
//  Status.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 27.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum Status: String, Decodable {
    case success = "Success"
    case validationError = "ValidationError"
    case protocolError = "ProtocolError"
    case serverError = "InternalServerError"
    case transactionProcessed = "TransactionAlreadyProcessed"
    case unknown
}
