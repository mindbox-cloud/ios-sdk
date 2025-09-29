//
//  StubDatabaseLoader.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/29/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData

final class StubDatabaseLoader: DatabaseLoading {
    func loadPersistentContainer() throws -> NSPersistentContainer { throw MBDatabaseError.unableCreateDatabaseModel }
    func makeInMemoryContainer() throws -> NSPersistentContainer { throw MBDatabaseError.unableCreateDatabaseModel }
    func destroy() throws {}
}
