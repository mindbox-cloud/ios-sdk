//
//  SdkVersionModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct SdkVersion: Decodable, Equatable {
    let min: Int?
    let max: Int?
}
