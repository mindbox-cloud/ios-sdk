//
//  LogCategory.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 07.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

public enum LogCategory: String, CaseIterable {

    case general
    case network
    case database
    case delivery
    case background
    case notification
    case visit
    case migration
    case inAppMessages

    var emoji: String {
        switch self {
        case .general:
            return "🤖"
        case .network:
            return "📡"
        case .database:
            return "📖"
        case .delivery:
            return "⚙️"
        case .background:
            return "🕳"
        case .notification:
            return "✉️"
        case .visit:
            return "👁"
        case .migration:
            return "✈️"
        case .inAppMessages:
            return "🖼️"
        }
    }
}
