//
//  TestBaseMigrations.swift
//  MindboxTests
//
//  Created by Sergei Semko on 8/6/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

final class TestBaseMigration_1: BaseMigration {
    override var description: String {
        "TestBaseMigration number 1"
    }

    override var isNeeded: Bool {
        true
    }

    override var version: Int {
        1
    }

    override func performMigration() throws {
        // Do some code
    }
}

final class TestBaseMigration_2: BaseMigration {
    override var description: String {
        "TestBaseMigration number 2"
    }

    override var isNeeded: Bool {
        true
    }

    override var version: Int {
        2
    }

    override func performMigration() throws {
        // Do some code
    }
}

final class TestBaseMigration_3_IsNeeded_False: BaseMigration {
    override var description: String {
        "TestBaseMigration number 3. isNeeded == false"
    }

    override var isNeeded: Bool {
        false
    }

    override var version: Int {
        3
    }

    override func performMigration() throws {
        // Do some code
    }
}

final class TestBaseMigration_4_WithPerfomError: BaseMigration {
    override var description: String {
        "TestBaseMigration number 4. perfromMigration throw error"
    }

    override var isNeeded: Bool {
        true
    }

    override var version: Int {
        4
    }

    override func performMigration() throws {
        // Do some code
        throw NSError(domain: "com.sdk.migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid version for migration"])
    }
}
