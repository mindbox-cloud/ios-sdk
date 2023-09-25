//
//  InappForm.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InAppFormDTO: Decodable, Equatable {
    let variants: [MindboxFormVariantDTO]?
}

struct InAppForm: Decodable, Equatable {
    let variants: [MindboxFormVariant]
}
