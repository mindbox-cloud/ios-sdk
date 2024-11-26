//
//  MockDatabaseRepository.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

final class MockDatabaseRepository: MBDatabaseRepository {

    var createsDeprecated: Bool = false
    var tempLimit: Int?

    override var limit: Int {
        tempLimit ?? super.limit
    }

    override var lifeLimitDate: Date? {
        createsDeprecated ? Date() : super.lifeLimitDate
    }
}
