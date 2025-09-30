//
//  DatabaseLoaderProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/19/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData

protocol DatabaseLoaderProtocol {
    func loadPersistentContainer() throws -> NSPersistentContainer
    func makeInMemoryContainer() throws -> NSPersistentContainer
    func destroy() throws
}
