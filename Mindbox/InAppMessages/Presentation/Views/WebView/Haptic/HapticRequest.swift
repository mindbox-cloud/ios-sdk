//
//  HapticRequest.swift
//  Mindbox
//
//  Created by Sergei Semko on 3/18/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import UIKit

enum HapticRequest: Equatable {
    case selection
    case impact(ImpactStyle)
    case notification(NotificationStyle)
    case pattern([HapticPatternEvent])

    enum ImpactStyle: String, CaseIterable {
        case light
        case medium
        case heavy
        case soft
        case rigid

        var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light:  return .light
            case .medium: return .medium
            case .heavy:  return .heavy
            case .soft:
                if #available(iOS 13.0, *) { return .soft } else { return .light }
            case .rigid:
                if #available(iOS 13.0, *) { return .rigid } else { return .heavy }
            }
        }
    }

    enum NotificationStyle: String, CaseIterable {
        case success
        case warning
        case error

        var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: return .success
            case .warning: return .warning
            case .error:   return .error
            }
        }
    }
}

struct HapticPatternEvent: Equatable {
    let time: Double
    let duration: Double
    let intensity: Double
    let sharpness: Double
}
