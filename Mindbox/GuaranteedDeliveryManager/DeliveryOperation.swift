//
//  DeliveryOperation.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class DeliveryOperation: Operation {
    
    private let event: Event
    
    private let databaseRepository: MBDatabaseRepository
    private let eventRepository: EventRepository

    init(databaseRepository: MBDatabaseRepository, eventRepository: EventRepository, event: Event) {
        self.databaseRepository = databaseRepository
        self.eventRepository = eventRepository
        self.event = event
    }
    
    var onCompleted: ((_ event: Event, _ error: ErrorModel?) -> Void)?
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get {
            return _isFinished
        }
        set {
            if #available(iOS 11.0, *) {
                willChangeValue(for: \.isFinished)
                _isFinished = newValue
                didChangeValue(for: \.isFinished)
            } else {
                willChangeValue(forKey: "isFinished")
                _isFinished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }
    
    override func main() {
        guard !isCancelled else {
            return
        }
        Log("Sending event with transactionId: \(event.transactionId), with number: \(event.serialNumber ?? "unknown")")
            .category(.delivery).level(.info).make()
        eventRepository.send(event: event) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success:
                self.onCompleted?(self.event, nil)
                Log("Did send event with transactionId: \(self.event.transactionId), with number: \(self.event.serialNumber ?? "unknown")")
                    .category(.delivery).level(.info).make()
                try? self.databaseRepository.delete(event: self.event)
                self.isFinished = true
            case .failure(let error):
                self.onCompleted?(self.event, error)
                Log("Did send event failed with error: \(error.localizedDescription), with number: \(self.event.serialNumber ?? "unknown")")
                    .category(.delivery).level(.error).make()
                if let statusCode = error.responseStatusCode, HTTPURLResponseStatusCodeValidator(statusCode: statusCode).isClientError {
                    try? self.databaseRepository.delete(event: self.event)
                } else {
                    try? self.databaseRepository.update(event: self.event)
                }
                self.isFinished = true
            }
        }
    }
    
}
