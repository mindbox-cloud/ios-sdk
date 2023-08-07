//
//  InappFormVariantContent.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InappFormVariantContent: Decodable, Equatable {
    let background: ContentBackground
    let elements: FailableDecodableArray<ContentElement>?
}
