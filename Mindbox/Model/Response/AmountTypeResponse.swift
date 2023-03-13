//
//  AmountTypeResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

public enum AmountTypeResponse: String, UnknownCodable {
    case quantity, discountAmount, unknown
}
