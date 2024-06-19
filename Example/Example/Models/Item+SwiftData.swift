//
//  SwiftData.swift
//  Example
//
//  Created by Sergei Semko on 6/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Mindbox
import SwiftData

@Model
public final class Item {
    public var timestamp: Date
    public var mbPushNotification: MBPushNotification
    
    public init(timestamp: Date, pushNotification: MBPushNotification) {
        self.timestamp = timestamp
        self.mbPushNotification = pushNotification
    }
}
