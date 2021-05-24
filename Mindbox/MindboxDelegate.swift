//
//  MindboxDelegate.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 19.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol MindboxDelegate: AnyObject {
    func mindBox(_ mindBox: Mindbox, failedWithError error: Error)
}
