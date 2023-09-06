//
//  CloseButtonElement.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct CloseButtonElementDTO: ContentElementProtocol {
    let color: FailableDecodable<String>?
    let lineWidth: FailableDecodable<Int>?
    let size: FailableDecodable<ContentElementSizeDTO>?
    let position: FailableDecodable<ContentElementPositionDTO>?
}

struct CloseButtonElement: ContentElementProtocol {
    let color: String
    let lineWidth: Int
    let size: ContentElementSize
    let position: ContentElementPosition
}
