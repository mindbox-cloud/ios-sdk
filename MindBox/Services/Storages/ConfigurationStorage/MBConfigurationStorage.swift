//
//  MBConfigurationStorage.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBConfigurationStorage: ConfigurationStorage {
    
    var domain: String = ""
    var endpoint: String = ""
    
    private(set) var startConfiguration: MBConfiguration?

    init() {}

    func save(configuration: MBConfiguration) {
        domain = configuration.domain
        endpoint = configuration.endpoint
        startConfiguration = configuration
    }

}
