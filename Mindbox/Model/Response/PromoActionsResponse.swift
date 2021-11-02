//
//  PromoActionsResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class PromoActionsResponse: Codable {
    public let ids: IDS?
    public let name: String?
    public let description: String?
    public let startDateTimeUtc: DateTime?
    public let endDateTimeUtc: DateTime?
    public let customFields: CustomFields?
    public let limits: [LimitResponse]?
}
