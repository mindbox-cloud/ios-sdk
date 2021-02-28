//
//  SaveEventOperation.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 28.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

final class SaveEventOperation: Operation {
    
    @Injected var databaseRepository: MBDatabaseRepository
        
    private let event: Event
    
    init(event: Event) {
        self.event = event
    }
    
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
    
    var onCompleted: ((_ result: Swift.Result<Event, Error>) -> Void)?

    override func main() {
        guard !isCancelled else {
            return
        }
        do {
            try databaseRepository.create(event: event)
            onCompleted?(.success(event))
            isFinished = true
        } catch let error {
            onCompleted?(.failure(error))
            isFinished = true
        }
    }
    
}
