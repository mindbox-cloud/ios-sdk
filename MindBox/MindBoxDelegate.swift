//
//  MindBoxDelegate.swift
//  MindBox
//
//  Created by Mikhail Barilov on 19.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public protocol MindBoxDelegate: class {

    /// Sdk will be called his method on installed case success
    func mindBoxDidInstalled()

    /// Sdk will be called this method on installed case fail
    func mindBoxInstalledFailed(error: MindBox.Errors)

    /// Sdk will be called this method on apns token did updated
    func apnsTokenDidUpdated()

}
