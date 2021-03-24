//
//  MockUNAuthorizationStatusProvider.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 09.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit
@testable import MindBox

class MockUNAuthorizationStatusProvider: UNAuthorizationStatusProviding {
    
    func getStatus(result: @escaping (Bool) -> Void) {
        result(status.rawValue == UNAuthorizationStatus.authorized.rawValue)
    }
    
    
    private let status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        self.status = status
    }
    
}
