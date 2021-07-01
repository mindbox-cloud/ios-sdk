//
//  PersonalOffersResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class PersonalOffersResponse: Decodable {
    public let product: ProductResponse?
    public let benefit: BenefitResponse?
    public let startDateTimeUtc: DateTime?
    public let endDateTimeUtc: DateTime?
}
