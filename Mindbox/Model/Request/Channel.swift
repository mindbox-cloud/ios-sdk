//
//  Channel.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 21.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public enum Channel: String, UnknownCodable {
    case email = "Email"
    case sms = "Sms"
    case viber = "Viber"
    case webPush = "WebPush"
    case mobilePush = "Mobilepush"
    case unknown
}
