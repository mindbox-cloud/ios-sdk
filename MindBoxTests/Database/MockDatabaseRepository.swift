//
//  MockDatabaseRepository.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 05.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

@testable import MindBox

class MockDatabaseRepository: MBDatabaseRepository {
    
    init() throws {
        let inMemoryDescription = NSPersistentStoreDescription()
        inMemoryDescription.type = NSInMemoryStoreType
        try super.init(persistentStoreDescriptions: [inMemoryDescription])
    }
    
}
