//
//  LogerConfiguration.swift
//  MindBox
//
//  Created by Mikhail Barilov on 25.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct LogConfiguration {
    
    var enabledCategories: [LogCategory] = [
        .general,
        .network,
        .database,
        .delivery,
        .background,
        .notification
    ]
}
