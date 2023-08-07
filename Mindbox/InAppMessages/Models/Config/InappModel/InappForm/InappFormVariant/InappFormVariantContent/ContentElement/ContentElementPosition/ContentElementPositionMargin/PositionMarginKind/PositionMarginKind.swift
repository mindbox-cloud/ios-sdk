//
//  PositionMarginKind.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum PositionMarginKind: String, Decodable, Equatable, DecodableWithUnknown {
    case proportion
    case unknown
}
