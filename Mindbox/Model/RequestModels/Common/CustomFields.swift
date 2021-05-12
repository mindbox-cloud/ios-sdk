//
//  CustomFields.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - CustomFields

public class CustomFields: Codable {
    public var int: Int?
    public var intArray: [Int]?
    public var string: String?
    public var stringArray: [String]?
    public var bool: Bool?
    public var float: Double?
    public var floatArray: [Double]?
    public var date: String?
    public var dateArray: [String]?
    public var dateAndTime: String?
    public var dateAndTimeArray: [String]?
    public var select: String?
    public var selectArray: [String]?

    public init(string: String?) {
        self.string = string
    }

    public init(
        int: Int?,
        intArray: [Int]?,
        string: String?,
        stringArray: [String]?,
        bool: Bool?,
        float: Double?,
        floatArray: [Double]?,
        date: String?,
        dateArray: [String]?,
        dateAndTime: String?,
        dateAndTimeArray: [String]?,
        select: String?,
        selectArray: [String]?
    ) {
        self.int = int
        self.intArray = intArray
        self.string = string
        self.stringArray = stringArray
        self.bool = bool
        self.float = float
        self.floatArray = floatArray
        self.date = date
        self.dateArray = dateArray
        self.dateAndTime = dateAndTime
        self.dateAndTimeArray = dateAndTimeArray
        self.select = select
        self.selectArray = selectArray
    }
}
