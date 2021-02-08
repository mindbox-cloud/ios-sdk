//
//  DeliveryOperation.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class DeliveryOperation: Operation {
    
    private let event: Event
    
    @Injected var eventRepository: EventRepository
    @Injected var databaseRepository: MBDatabaseRepository
    
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
    
    override func main() {
        guard !isCancelled else {
            return
        }
        Log("Sending event with transactionId: \(event.transactionId)")
            .inChanel(.delivery).withType(.info).make()
        eventRepository.send(event: event) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success:
                Log("Did send event with transactionId: \(self.event.transactionId)")
                    .inChanel(.delivery).withType(.info).make()
                try? self.databaseRepository.delete(event: self.event)
                self.isFinished = true
            case .failure(let error):
                Log("Did send event failed with error: \(error.localizedDescription)")
                    .inChanel(.delivery).withType(.error).make()
                self.isFinished = true
            }
        }
    }
    
}
