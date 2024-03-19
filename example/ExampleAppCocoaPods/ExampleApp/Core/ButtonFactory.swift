//
//  Factory.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/19/24.
//

import UIKit

protocol ButtonFactory {
    func createButton(type: ButtonType) -> UIButton
}

enum ButtonType {
    case copy
    case trigger
}

final class EAButtonFactory: ButtonFactory {
    func createButton(type: ButtonType) -> UIButton {
        switch type {
        case .copy:
            return UIButton(title: .copy, image: .copy)
        case .trigger:
            return UIButton(title: .trigger, image: .trigger)
        }
    }
}
