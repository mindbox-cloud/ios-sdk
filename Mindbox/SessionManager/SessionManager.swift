//
//  SessionManager.swift
//  Mindbox
//
//  Created by Egor Kitseliuk on 22.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol SessionManager: AnyObject {

    var isActiveNow: Bool { get }
    var sessionHandler: ((Bool) -> Void)? { get set }

    func trackDirect()

    func trackForeground()
}
