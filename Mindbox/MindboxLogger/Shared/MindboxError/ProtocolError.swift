//
//  ProtocolError.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 27.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public struct ProtocolError: Codable, CustomStringConvertible {
    public let status: Status
    /// Error description
    public let errorMessage: String
    /// UUID of error
    public let errorId: String?
    /// Error's http code
    public let httpStatusCode: Int

    public var description: String {
        var string: String = ""

        string += "\nStatus code: \(httpStatusCode)"
        string += "\nMessage: \(errorMessage)"
        if let errorId = errorId {
            string += "\nErrorID: \(errorId)"
        }

        return string
    }

    public init(status: Status, errorMessage: String, httpStatusCode: Int, errorId: String? = nil) {
        self.status = status
        self.errorMessage = errorMessage
        self.httpStatusCode = httpStatusCode
        self.errorId = errorId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        httpStatusCode = try container.decode(Int.self, forKey: .httpStatusCode)
        status = try container.decode(Status.self, forKey: .status)
        errorMessage = try container.decode(String.self, forKey: .errorMessage)
        errorId = try container.decodeIfPresent(String.self, forKey: .errorId)
    }

    enum Keys: String, CodingKey {
        case httpStatusCode
        case status
        case errorMessage
        case errorId
    }
}
