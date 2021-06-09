//
//  AmountResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class AmountResponse: Decodable {
    public let type: AmountTypeResponse?
    public let value: Double?
}
