//
//  AppConstants.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/19/24.
//

import UIKit

enum Constants {
    
    enum Buttons {
        enum Title: String {
            case copy = "Copy"
            case trigger = "Trigger In-App"
        }
        
        enum ImageName: String {
            case copy = "doc.on.doc"
            case trigger = "icloud.and.arrow.up"
        }
    }
    
//    static let copyButtonTitle = "Copy"
//    static let copyButtonSystemImageName = "doc.on.doc"
//    
//    static let inAppTriggerButtonTitle = "Trigger In-App"
//    static let inAppTriggerButtonSystemImageName = "icloud.and.arrow.up"
    
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
