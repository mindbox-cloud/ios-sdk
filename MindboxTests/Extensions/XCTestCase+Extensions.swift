//
//  XCTestCase+Extensions.swift
//  MindboxTests
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

extension XCTestCase {
    open override func setUp() {
        super.setUp()
        TestConfiguration.configure()
    }
}
