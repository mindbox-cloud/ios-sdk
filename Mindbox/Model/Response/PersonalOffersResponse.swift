//
//  PersonalOffersResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class PersonalOffersResponse: Codable {
    public let product: ProductResponse?
    public let benefit: BenefitResponse?
    public let startDateTimeUtc: DateTime?
    public let endDateTimeUtc: DateTime?
}
