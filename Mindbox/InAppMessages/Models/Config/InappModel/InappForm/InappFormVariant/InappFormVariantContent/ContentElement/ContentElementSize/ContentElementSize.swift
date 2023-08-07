//
//  ContentElementSize.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct ContentElementSize: Decodable, Equatable {
    let kind: ContentElementSizeKind
    let width: Double
    let height: Double
}
