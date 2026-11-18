//
//  ImageFormat.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

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

    var attachmentOptions: [AnyHashable: Any]? {
        switch self {
        case .gif:
            return [UNNotificationAttachmentOptionsThumbnailTimeKey: 0]
        case .png, .jpg:
            return nil
        }
    }
}

extension ImageFormat {
    static func get(from data: Data) -> ImageFormat? {
        guard let firstByte = data.first else {
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
            return nil
        }
    }
}
