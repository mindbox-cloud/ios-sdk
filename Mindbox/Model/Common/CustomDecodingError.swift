//
//  CustomDecodingError.swift
//  Mindbox
//
//  Created by vailence on 10.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

enum CustomDecodingError: Error {
    case decodingError(String)
    case unknownType(String)
}
