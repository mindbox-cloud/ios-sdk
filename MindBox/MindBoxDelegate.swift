//
//  MindBoxDelegate.swift
//  MindBox
//
//  Created by Mikhail Barilov on 19.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol MindBoxDelegate: class {

    func mindBox(_ mindBox: MindBox, failedWithError error: Error)
    
}
