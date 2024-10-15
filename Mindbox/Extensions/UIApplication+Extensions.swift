//
//  UIApplication+Extensions.swift
//  Mindbox
//
//  Created by Sergei Semko on 5/2/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit

extension UIApplication {
    var appStateDescription: String {
        if Thread.isMainThread {
            return describeApplicationState
        } else {
            return DispatchQueue.main.sync {
                describeApplicationState
            }
        }
    }

    private var describeApplicationState: String {
        switch applicationState {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
