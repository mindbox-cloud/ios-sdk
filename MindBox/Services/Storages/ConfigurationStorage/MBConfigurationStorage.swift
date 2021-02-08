//
//  MBConfigurationStorage.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBConfigurationStorage: ConfigurationStorage {
    
    var configuration: MBConfiguration?

    func setConfiguration(_ configuration: MBConfiguration) {
        self.configuration = configuration
    }
    
    func set(uuid: String) {
        configuration?.deviceUUID = uuid
    }

}
