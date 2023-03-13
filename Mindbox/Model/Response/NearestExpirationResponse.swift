//
//  NearestExpirationResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class NearestExpirationResponse: Codable {
    public let total: Double?
    public let date: DateOnly?
}
