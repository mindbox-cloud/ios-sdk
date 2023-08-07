//
//  InappFormVariantType.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum InappFormVariantType: String, Decodable, Equatable, DecodableWithUnknown {
    case modal
    case snackbar
    case unknown
}
