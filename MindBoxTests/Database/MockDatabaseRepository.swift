//
//  MockDatabaseRepository.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import MindBox

class MockDatabaseRepository: MBDatabaseRepository {
    
    var createsDeprecated: Bool = false
    
    override var lifeLimitDate: Date? {
        createsDeprecated ? Date() : super.lifeLimitDate
    }
}
