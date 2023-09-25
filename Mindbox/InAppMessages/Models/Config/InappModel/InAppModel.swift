//
//  InAppModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InAppDTO: Decodable, Equatable {
    let id: String
    let sdkVersion: SdkVersion
    let targeting: Targeting
    let form: InAppFormDTO
}

struct InApp: Decodable, Equatable {
    let id: String
    let sdkVersion: SdkVersion
    let targeting: Targeting
    let form: InAppForm
}
