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
                .registerCore()
                .registerUtilitiesServices()
                .registerABTestUtilities()
                .registerInappTools()
                .registerInappPresentation()
                .registerMocks()
        }

        MBInject.mode = .test
    }
}

extension ConfigResponse {
    /// Candidates the way the configuration manager builds them, so a selection test starts where production starts.
    var candidates: ConfigCandidates {
        DI.injectOrFail(InappFilterProtocol.self).candidates(from: self)
    }
}
