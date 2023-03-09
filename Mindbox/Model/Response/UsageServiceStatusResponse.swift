//
//  UsageServiceStatusResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

public enum UsageServiceStatusResponse: String, UnknownCodable {
    case available, unavailable, unknown
}
