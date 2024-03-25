//
//  MockSessionManager.swift
//  MindboxTests
//
//  Created by Egor Kitseliuk on 22.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

class MockSessionManager: SessionManager {

    public var _isActiveNow: Bool = false
    var isActiveNow: Bool { return _isActiveNow }
    
    var sessionHandler: ((Bool) -> Void)? = { isActive in }
    
    func trackDirect() {}
    
    func trackForeground() { }

}
