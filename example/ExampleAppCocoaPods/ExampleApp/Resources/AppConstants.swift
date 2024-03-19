//
//  AppConstants.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/19/24.
//

import UIKit

enum Constants {
    
    static let NotificationCenterName = "MindboxNotificationReceived"
    
    static let inAppTriggerButtonTitle = "Trigger In-App: Sync Operation"
    static let inAppTriggerButtonImage = UIImage(systemName: "icloud.and.arrow.up")
    
    static let copyActionTitle = "Copy"
    static let copyActionImage = UIImage(systemName: "doc.on.doc")
    
    static let mindboxColor = UIColor(
        red: 91 / 255,
        green: 168 / 255,
        blue: 101 / 255,
        alpha: 1
    )
    
    static let startAlpha: CGFloat = 0
    static let endAlpha: CGFloat = 1
    
    static let cornerRadius: CGFloat = 15
    
    static let animationDuration: TimeInterval = 0.5
}
