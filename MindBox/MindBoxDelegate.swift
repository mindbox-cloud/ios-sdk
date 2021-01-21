//
//  MindBoxDelegate.swift
//  MindBox
//
//  Created by Mikhail Barilov on 19.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public protocol MindBoxDelegate: class {
    func mindBoxDidInstalled()
    func mindBoxInstalledFailed(error: MindBox.Errors)
    func apnsTokenDidUpdated()

    func mindBoxDidConfigured()

}
