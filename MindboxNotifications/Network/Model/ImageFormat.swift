//
//  ImageFormat.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum ImageFormat: String {
    case png, jpg, gif

    init?(_ data: Data) {
        if let type = ImageFormat.get(from: data) {
            self = type
        } else {
            return nil
        }
    }

    var `extension`: String {
        return rawValue
    }
}

extension ImageFormat {
    static func get(from data: Data) -> ImageFormat? {
        switch data[0] {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        default:
            return nil
        }
    }
}
