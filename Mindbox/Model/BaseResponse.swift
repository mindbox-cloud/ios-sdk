//
//  BaseResponse.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 18.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import MindboxLogger

class BaseResponse: Decodable {
    var status: Status = .unknown
}
