//
//  DeliveryOperation.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class DeliveryOperation: AsyncOperation, @unchecked Sendable {
    private let event: Event

    private let databaseRepository: MBDatabaseRepository
    private let eventRepository: EventRepository

    init(databaseRepository: MBDatabaseRepository, eventRepository: EventRepository, event: Event) {
        self.databaseRepository = databaseRepository
        self.eventRepository = eventRepository
        self.event = event
    }

    var onCompleted: ((_ event: Event, _ error: MindboxError?) -> Void)?

    override func main() {
        Logger.common(message: "Sending event with transactionId: \(event.transactionId), with number: \(event.serialNumber ?? "unknown")", level: .info, category: .delivery)
        eventRepository.send(event: event) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.onCompleted?(self.event, nil)
                Logger.common(message: "Did send event with transactionId: \(self.event.transactionId), with number: \(self.event.serialNumber ?? "unknown")", level: .info, category: .delivery)
                try? self.databaseRepository.delete(event: self.event)
            case let .failure(error):
                self.onCompleted?(self.event, error)
                Logger.common(message: "Did send event failed with error: \(error.localizedDescription), with number: \(self.event.serialNumber ?? "unknown")", level: .error, category: .delivery)
                if case let MindboxError.protocolError(response) = error, HTTPURLResponseStatusCodeValidator(statusCode: response.httpStatusCode).isClientError {
                    try? self.databaseRepository.delete(event: self.event)
                } else {
                    try? self.databaseRepository.update(event: self.event)
                }
            }
            self.finish()
        }
    }

}
