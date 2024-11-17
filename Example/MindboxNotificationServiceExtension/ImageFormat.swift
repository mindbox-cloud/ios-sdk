//
//  ImageFormat.swift
//  MindboxNotificationServiceExtension
//
//  Created by Sergei Semko on 11/15/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

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
        guard let firstByte = data.first else {
            Logger.common(message: "ImageFormat: Failed to get firstByte", level: .error, category: .notification)
            return nil
        }
        switch firstByte {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        default:
            Logger.common(message: "ImageFormat: Failed to get image format", level: .error, category: .notification)
            return nil
        }
    }
}
