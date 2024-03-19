//
//  Extensions.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/19/24.
//

import UIKit

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

extension UIButton {
    convenience init(title: Constants.Buttons.Title, image: Constants.Buttons.ImageName) {
        self.init(type: .system)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.setTitle(title.rawValue, for: .normal)
        self.setImage(
            UIImage(systemName: image.rawValue),
            for: .normal
        )
        self.backgroundColor = Constants.mindboxColor
        self.tintColor = .white
        self.alpha = Constants.startAlpha
        self.layer.cornerRadius = Constants.cornerRadius
    }
}

extension UILabel {
    convenience init(numberOfLines: Int) {
        self.init()
        self.translatesAutoresizingMaskIntoConstraints = false
        self.numberOfLines = numberOfLines
        self.textAlignment = .center
        self.alpha = Constants.startAlpha
    }
}
