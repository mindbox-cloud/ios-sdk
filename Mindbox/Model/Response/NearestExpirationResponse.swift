//
//  NearestExpirationResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class NearestExpirationResponse: Decodable {
    public let total: Double?
    public let date: DateOnly?
}
