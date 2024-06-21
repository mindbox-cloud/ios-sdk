//
//  StubContainer.swift
//  MindboxTests
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

enum TestConfiguration {
    static func configure() {
        MBInject.buildTestContainer = {
            let container = MBContainer()
            return container
                .registerMocks()
        }
        
        MBInject.mode = .test
    }
}

fileprivate extension MBContainer {
    func registerMocks() -> Self {
        return self
    }
}