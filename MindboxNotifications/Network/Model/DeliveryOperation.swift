//
//  DeliveryOperation.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

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
            guard let self = self else {
                Logger.common(message: "PushDeliveryOperation: Failed to get PushDeliveryOperation. self: \(String(describing: self))", level: .error, category: .notification)
                return
            }
            switch result {
            case true:
                self.onCompleted?(self.event, true)
                self.isFinished = true
                Logger.common(message: "PushDeliveryOperation: result: \(result), onCompleted: \(String(describing: self.onCompleted))", level: .info, category: .notification)
            case false:
                self.onCompleted?(self.event, false)
                self.isFinished = true
                Logger.common(message: "PushDeliveryOperation: result: \(result), onCompleted: \(String(describing: self.onCompleted))", level: .error, category: .notification)
            }
        }
    }
}
