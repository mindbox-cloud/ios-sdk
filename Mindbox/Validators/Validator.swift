//
//  Validator.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol Validator {
    associatedtype T
    func isValid(item: T) -> Bool
}
