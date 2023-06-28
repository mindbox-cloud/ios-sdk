//
//  LoggerErrorModel.swift
//  MindboxLogger
//
//  Created by vailence on 22.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

public struct LoggerErrorModel {
    public init(errorType: LoggerErrorType, description: String? = nil, status: String? = nil, statusCode: Int? = nil, errorKey: String? = nil) {
        self.errorType = errorType
        self.description = description
        self.status = status
        self.statusCode = statusCode
        self.errorKey = errorKey
    }
    
    let errorType: LoggerErrorType
    let description: String?
    let status: String?
    let statusCode: Int?
    let errorKey: String?
}

public enum LoggerErrorType: String {
    case validation
    case `protocol`
    case server
    case `internal`
    case invalid
    case connection
    case unknown
}
