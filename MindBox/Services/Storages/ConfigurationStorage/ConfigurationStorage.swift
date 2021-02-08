//
//  ConfigurationStorage.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol ConfigurationStorage: class {
    
    var domain: String { get set }
    var endpoint: String { get set }
    var startConfiguration: MBConfiguration? { get }

    func save(configuration: MBConfiguration)
    
    func set(uuid: String)
    
}
