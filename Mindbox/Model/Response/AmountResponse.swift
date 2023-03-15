//
//  AmountResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

open class AmountResponse: Codable {
    public let type: AmountTypeResponse?
    public let value: Double?
}
