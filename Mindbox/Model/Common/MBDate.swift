//
//  MBDate.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 19.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public final class DateOnlyRequest: MBDate {
    override var dateFormat: String {
        "dd.MM.yyyy"
    }
}

public final class DateTimeRequest: MBDate {
    override var dateFormat: String {
        "dd.MM.yyyy HH:mm:ss.FFF"
    }
}

public class MBDate: Encodable {
    public var string: String {
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: date)
    }

    public let date: Date
    private let dateFormatter = DateFormatter()

    var dateFormat: String {
        return ""
    }

    public init(_ date: Date) {
        self.date = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension Date {
    public var asDateOnlyRequest: DateOnlyRequest {
        return DateOnlyRequest(self)
    }

    public var asDateTimeRequest: DateTimeRequest {
        return DateTimeRequest(self)
    }
}
