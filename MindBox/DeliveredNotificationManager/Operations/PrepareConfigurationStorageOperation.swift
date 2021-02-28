//
//  PrepareConfigurationStorageOperation.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 28.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

final class PrepareConfigurationStorageOperation: Operation {
    
    @Injected var persistenceStorage: PersistenceStorage
    @Injected var configurationStorage: ConfigurationStorage
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get {
            return _isFinished
        }
        set {
            willChangeValue(for: \.isFinished)
            _isFinished = newValue
            didChangeValue(for: \.isFinished)
        }
    }
    
    override func main() {
        guard !isCancelled else {
            return
        }
        if let configuration = persistenceStorage.configuration {
            configurationStorage.setConfiguration(configuration)
        }
        isFinished = true
    }
    
}
