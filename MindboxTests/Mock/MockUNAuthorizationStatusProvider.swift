//
//  MockUNAuthorizationStatusProvider.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 09.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit
@testable import Mindbox

class MockUNAuthorizationStatusProvider: UNAuthorizationStatusProviding {
    
    func getStatus(result: @escaping (Bool) -> Void) {
        result(status.rawValue == UNAuthorizationStatus.authorized.rawValue)
    }
    
    
    private let status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        self.status = status
    }
    
}
