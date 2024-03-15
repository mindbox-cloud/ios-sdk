//
//  Extensions.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/13/24.
//

import UIKit

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

