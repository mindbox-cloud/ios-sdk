//
//  DITest.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 28.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//


import XCTest
@testable import Mindbox

final class TestDependencyProvider: DependencyContainer {
    let utilitiesFetcher: UtilitiesFetcher
    let databaseRepository: MBDatabaseRepository
    
    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
    }
}

