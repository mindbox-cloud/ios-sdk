//
//  CoreController.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class CoreController {

    @Injected var loger: ILoger!
    @Injected var configurationStorage: IConfigurationStorage
    @Injected var persistenceStorage: IPersistenceStorage
    @Injected var apiServices: IMindBoxAPIService
    
    init() {

    }
    
    
}
