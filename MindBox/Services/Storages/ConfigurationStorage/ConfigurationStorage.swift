//
//  ConfigurationStorage.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol ConfigurationStorage: class {

    var configuration: MBConfiguration? { get }

    func setConfiguration(_ configuration: MBConfiguration)
    
    func set(uuid: String)
    
}
