//
//  Extensions.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/19/24.
//

import UIKit
import OSLog

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

extension UIStackView {
    func addArrangedSubviews(_ views: UIView...) {
        views.forEach { addArrangedSubview($0) }
    }
}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let logManager = Logger(subsystem: subsystem, category: "logManager")
}
