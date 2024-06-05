//
//  SetupDIForTesting.swift
//  MindboxTests
//
//  Created by Sergei Semko on 6/5/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

extension Container {
    func registerMocks() -> Self {
        register(PersistenceStorage.self) {
            MockPersistenceStorage()
        }
        
        return self
    }
}

extension MBInject {
    static var test: Self.Type {
        Self.mode = .test{ container in
            container
                .registerMocks()
        }
        
        return self
    }
}

var testContainer: ModuleInjector {
    MBInject.test.depContainer
}
