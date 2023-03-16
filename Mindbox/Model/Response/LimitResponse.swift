//
//  LimitResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class LimitResponse: Codable {
    public let type: LimitTypeResponse?
    public let amount: AmountResponse?
    public let used: UsedResponse?
    public let untilDateTimeUtc: DateTime?
}
