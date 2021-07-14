//
//  ValidationError.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 27.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public struct ValidationError: Decodable, CustomStringConvertible {
    public let status: Status
    /// Array of validation problems
    public let validationMessages: [ValidationMessage]

    public var description: String {
        return validationMessages.map { "Field \($0.location ?? "no location") error. Message: \($0.message ?? "no message")" }.joined(separator: ";\n")
    }
}

public struct ValidationMessage: Codable {
    /// Message for specified field
    public let message: String?
    /// Location of field
    public let location: String?
}
