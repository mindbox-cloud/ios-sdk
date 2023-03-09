//
//  LimitTypeResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

public enum LimitTypeResponse: String, UnknownCodable {
    case groupLimit, personalLimit, unknown
}
