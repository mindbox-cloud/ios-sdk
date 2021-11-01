//
//  BalancesResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class BalanceResponse: Codable {
    public let total: Double?
    public let available: Double?
    public let blocked: Double?
    public let nearestExpiration: NearestExpirationResponse?
    public let systemName: String?
    public let balanceType: BalanceTypeReponse?
}
