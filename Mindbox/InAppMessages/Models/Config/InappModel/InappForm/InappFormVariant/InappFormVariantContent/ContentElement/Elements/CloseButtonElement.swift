//
//  CloseButtonElement.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct CloseButtonElement: ContentElementProtocol {
    let color: String?
    let lineWidth: Int?
    let size: FailableDecodable<ContentElementSize>?
    let position: ContentElementPosition?
}
