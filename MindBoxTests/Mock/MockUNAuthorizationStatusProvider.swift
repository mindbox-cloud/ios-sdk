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

    private let status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func isAuthorized(completion: @escaping (Bool) -> Void) {
        completion(status.rawValue == UNAuthorizationStatus.authorized.rawValue)
    }
    
}
