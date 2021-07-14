//
//  DeliveryOperation.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class PushDeliveryOperation: Operation {
    private let event: Event
    private let service: NetworkService

    init(event: Event, service: NetworkService) {
        self.event = event
        self.service = service
    }

    var onCompleted: ((_ event: Event, _ success: Bool) -> Void)?

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

        service.sendPushDelivered(event: event) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case true:
                self.onCompleted?(self.event, true)
                self.isFinished = true
            case false:
                self.onCompleted?(self.event, false)
                self.isFinished = true
            }
        }
    }
}
