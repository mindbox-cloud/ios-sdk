//
//  MockDatabaseRepository.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 05.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import CoreData

@testable import Mindbox

class MockDataBaseLoader: DataBaseLoader {
    
    init() throws {
        let inMemoryDescription = NSPersistentStoreDescription()
        inMemoryDescription.type = NSInMemoryStoreType
        try super.init(persistentStoreDescriptions: [inMemoryDescription])
    }
}
