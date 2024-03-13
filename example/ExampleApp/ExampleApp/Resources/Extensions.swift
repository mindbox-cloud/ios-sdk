//
//  Extensions.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/13/24.
//

import UIKit
import OSLog

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let mindboxInAppActions = Logger(subsystem: subsystem, category: "InAppActions")
}

