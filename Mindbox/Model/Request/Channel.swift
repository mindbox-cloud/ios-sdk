//
//  Channel.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum Channel: String, Codable {
    case email = "Email"
    case sms = "SMS"
    case viber = "Viber"
    case webPush = "Webpush"
    case mobilePush = "Mobilepush"
}
