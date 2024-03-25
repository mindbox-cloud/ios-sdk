//
//  ImageFormat.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
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
            Logger.common(message: "ImageFormat: Failed to get firstByte. data \(data)", level: .error, category: .notification)
            return nil
        }
        switch firstByte {
        case 0x89:
            Logger.common(message: "ImageFormat: Successfully identified image format as .png", level: .info, category: .notification)
            return .png
        case 0xFF:
            Logger.common(message: "ImageFormat: Successfully identified image format as .jpg", level: .info, category: .notification)
            return .jpg
        case 0x47:
            Logger.common(message: "ImageFormat: Successfully identified image format as .gif", level: .info, category: .notification)
            return .gif
        default:
            Logger.common(message: "ImageFormat: Failed to get image format", level: .fault, category: .notification)
            return nil
        }
    }
}
