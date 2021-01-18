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
}

class MBConfigurationStorage: IConfigurationStorage {

    var domain: String = ""
    var endpoint: String = ""
}
