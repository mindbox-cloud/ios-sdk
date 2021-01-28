//
//  ConfigurationStorage.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IConfigurationStorage: class {
    var domain: String {get set}
    var endpoint: String {get set}
    var startConfiguration: MBConfiguration? {get}

    func save(configuration: MBConfiguration)
}

class MBConfigurationStorage: IConfigurationStorage {
    var domain: String = ""
    var endpoint: String = ""
    private(set) var startConfiguration: MBConfiguration?

    init() {
        
    }

    func save(configuration: MBConfiguration) {
        self.domain = configuration.domain
        self.endpoint = configuration.endpoint
        self.domain = configuration.domain
        startConfiguration = configuration
    }

}
